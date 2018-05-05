--
--  K1208 Main CPLD Logic (Xilinx XC95144XL)
--
--  Copyright (C) 2018 Mike Stirling
--
--  This program is free software: you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation, either version 3 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program.  If not, see <https://www.gnu.org/licenses/>.
--
--
--  SPI interface and related functions
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spi is
port (
	CLOCK		:	in		std_logic;
	nRESET		:	in		std_logic;
	
	ENABLE		:	in		std_logic;
	WR			:	in		std_logic;
	A			:	in		std_logic_vector(1 downto 0);
	D_IN		:	in		std_logic_vector(7 downto 0);
	D_OUT		:	out		std_logic_vector(7 downto 0);
	BUSY_OUT	:	out		std_logic;	-- Busy output to DSACK for wait-state insertion (active high)
	
	-- Aux interrupt routing
	nEXT_INT	:	in		std_logic;	-- External interrupt signal (low-level 
	INT_OUT		:	out		std_logic;	-- Interrupt output (active high)

	-- SPI port
	SPI_nCS		:	out		std_logic_vector(1 downto 0);
	SPI_SCLK	:	out		std_logic;
	SPI_MOSI	:	out		std_logic;
	SPI_MISO	:	in		std_logic
	);
end entity;

architecture rtl of spi is
-- Control register
signal cpha		:	std_logic;		-- 0 = data captured on first edge, 1 = data captured on second edge
signal cpol		:	std_logic;		-- 0 = clock idles low, 1 = clock idles high
signal slow		:	std_logic;		-- 0 = 7.1 MHz, 1 = 222 kHz (for SD card init) (a full programmable divider wouldn't fit)
signal cs		:	std_logic_vector(1 downto 0);
signal intena	:	std_logic;		-- 0 = external interrupt disabled, 1 = external interrupt routed to INT_OUT
-- Status register
signal busy		:	std_logic;
-- Clock divider (/32 for slow mode)
signal clkcnt	:	unsigned(4 downto 0);
-- Bit counter
signal bitcnt	:	unsigned(3 downto 0);
-- Data
signal shiftreg	:	std_logic_vector(7 downto 0);

signal clken	:	std_logic;
signal regout	:	std_logic_vector(7 downto 0);

-- Port signals
signal mosi		:	std_logic;
signal miso		:	std_logic;
signal clkout	:	std_logic;
begin
	-- Ports
	SPI_nCS <= not cs;
	SPI_MOSI <= mosi;
	miso <= SPI_MISO;
	SPI_SCLK <= clkout;
	
	-- Read mux
	with "00" & A select
		regout <=
			"0" & intena & cs & "0" & slow & cpol & cpha 	when X"00",	-- CR
			"0000000" & busy			when X"01",	-- SR
			shiftreg					when X"03", -- DR
			X"00"						when others;

	-- Register data out
	-- (doing this or not is a balance between product terms and overall macrocell count)
--	read_cycle: process(CLOCK,nRESET)
--	begin
--		if nRESET='0' then
--			D_OUT <= (others => '0');
--		elsif rising_edge(CLOCK) then
--			D_OUT <= regout;
--		end if;
--	end process;
	D_OUT <= regout;
	BUSY_OUT <= busy; -- Expose busy flag to enable wait-states to be inserted instead of polling SR
	INT_OUT <= intena and not nEXT_INT;

	-- Write path and IO
	write_cycle: process(CLOCK, nRESET)
	begin
		if nRESET='0' then
			-- Default all control registers
			cpha <= '0';
			cpol <= '0';
			slow <= '0';
			cs <= (others => '0');
			shiftreg <= (others => '0');
			
			-- Default all state
			busy <= '0';
			bitcnt <= (others => '0');
			
			-- Outputs to port
			clkout <= '0';
			mosi <= '0';
		elsif rising_edge(CLOCK) then		
			-- SPI bus cycle when clock enable asserted
			if clken='1' then
				if busy='1' then
					bitcnt <= bitcnt + 1;
					if bitcnt = 15 then
						busy <= '0';
					end if;
					
					clkout <= bitcnt(0) xor cpol;
					if bitcnt(0)=cpha then
						mosi <= shiftreg(7);
					else
						shiftreg <= shiftreg(6 downto 0) & miso;
					end if;
				else
					clkout <= cpol;
				end if;
			end if;
			
			-- Register writes
			if ENABLE='1' then
				if WR='1' then 
					case "00" & A is
						when X"0" =>
							-- CR
							cpha <= D_IN(0);
							cpol <= D_IN(1);
							slow <= D_IN(2);
							cs <= D_IN(5 downto 4);
							intena <= D_IN(6);
						when X"1" =>
							-- SR (read-only)
							null;
						when X"3" =>
							-- DR
							if busy='0' then
								-- Write to txreg initiates transfer (does not ack bus cycle until SPI is complete)
								shiftreg <= D_IN;
								busy <= '1';
								bitcnt <= (others => '0');
							end if;
						when others =>
							null;
					end case;
				end if;
			end if;
		end if;
	end process;
	
	-- Clock divider (for slow mode)
	process(CLOCK, nRESET)
	begin
		if nRESET='0' then
			clken <= '0';
			clkcnt <= (others => '0');
		elsif rising_edge(CLOCK) then
			clken <= not slow;
			
			-- /32 if in slow mode
			clkcnt <= clkcnt + 1;
			if clkcnt=0 then
				clken <= '1';
			end if;
		end if;
	end process;

end architecture;

