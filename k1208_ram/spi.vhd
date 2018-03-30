----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    19:46:08 03/27/2018 
-- Design Name: 
-- Module Name:    spi - rtl 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
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

	SPI_nCS		:	out		std_logic_vector(3 downto 0);
	SPI_SCLK	:	out		std_logic;
	SPI_MOSI	:	out		std_logic;
	SPI_MISO	:	in		std_logic
	);
end entity;

architecture rtl of spi is
-- Control register
signal cpha		:	std_logic;		-- 0 = data captured on first edge, 1 = data captured on second edge
signal cpol		:	std_logic;		-- 0 = clock idles low, 1 = clock idles high
signal cs		:	std_logic_vector(3 downto 0);
-- Status register
signal busy		:	std_logic;
-- Clock divider
signal clkdiv	:	unsigned(7 downto 0);
signal clkdiv_counter	:	unsigned(7 downto 0);
-- Bit counter
signal bitcnt	:	unsigned(3 downto 0);
-- Data
signal shiftreg	:	std_logic_vector(7 downto 0);

signal clken	:	std_logic;
signal read_reg	:	std_logic_vector(7 downto 0);

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
		read_reg <=
			cs & "00" & cpol & cpha 	when X"00",	-- CR
			"0000000" & busy			when X"01",	-- SR
--			std_logic_vector(clkdiv)	when X"02", -- CLKDIV
			shiftreg					when X"03", -- DR
			X"00"						when others;

	-- Register data out
	-- (doing this or not is a balance between product terms and overall macrocell count)
--	read_cycle: process(CLOCK,nRESET)
--	begin
--		if nRESET='0' then
--			D_OUT <= (others => '0');
--		elsif rising_edge(CLOCK) then
--			D_OUT <= read_reg;
--		end if;
--	end process;
	D_OUT <= read_reg;

	-- Write path and IO
	write_cycle: process(CLOCK, nRESET)
	begin
		if nRESET='0' then
			-- Default all control registers
			cpha <= '0';
			cpol <= '0';
			cs <= (others => '0');
--			clkdiv <= (others => '0');
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
			if ENABLE='1' and WR='1' then
				case "00" & A is
					when X"00" =>
						-- CR
						cpha <= D_IN(0);
						cpol <= D_IN(1);
						cs <= D_IN(7 downto 4);
					when X"01" =>
						-- SR (read-only)
						null;
					when X"02" =>
						-- CLKDIV
--						clkdiv <= unsigned(D_IN);
					when X"03" =>
						-- DR
						if busy='0' then
							-- Write to txreg initiates transfer
							shiftreg <= D_IN;
							busy <= '1';
							bitcnt <= (others => '0');
						end if;
					when others =>
						null;
				end case;
			end if;
		end if;
	end process;
	
	-- Clock divider
	process(CLOCK, nRESET)
	begin
		if nRESET='0' then
			clken <= '1';
--			clken <= '0';
--			clkdiv_counter <= (others => '0');
		elsif rising_edge(CLOCK) then
			clken <= '1';
--			clken <= '0';
--			clkdiv_counter <= clkdiv_counter + 1;
--			
--			if clkdiv_counter = clkdiv then
--				clkdiv_counter <= (others => '0');
--				clken <= '1';
--			end if;
		end if;
	end process;

end architecture;

