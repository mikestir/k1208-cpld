----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    10:43:05 03/25/2018 
-- Design Name: 
-- Module Name:    fastmem - rtl 
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

entity fastmem is
port (
	CLOCK		:	in		std_logic;
	nRESET		:	in		std_logic;
	
	R_nW		:	in		std_logic;
	nAS			:	in		std_logic;
	A			:	in		std_logic_vector(23 downto 0);
	SIZE		:	in		std_logic_vector(1 downto 0);

	RAM_SEL		:	out		std_logic;
	ROW_MUX		:	out		std_logic; -- selects row address
	RAM_A		:	out		std_logic_vector(1 downto 0);
	nOE			:	out		std_logic;
	nRAS		:	out		std_logic_vector(1 downto 0);
	nCAS		:	out		std_logic_vector(3 downto 0)
	);
end entity;

architecture rtl of fastmem is
type state_t is (Idle, RASState, CASState);
signal state		:		state_t;
signal addr_valid	:		std_logic;
signal addr_valid_reg	:	std_logic;
signal bank_sel		:		std_logic_vector(3 downto 0);
signal chip_sel		:		std_logic_vector(1 downto 0);
signal byte_sel		:		std_logic_vector(3 downto 0);
signal row_enable	:		std_logic;
begin
	-- Address decoding
	addr_valid <= nRESET and not nAS;
	bank_sel(0) <= '1' when A(23 downto 21)="001" and addr_valid='1' else '0';
	bank_sel(1) <= '1' when A(23 downto 21)="010" and addr_valid='1' else '0';
	bank_sel(2) <= '1' when A(23 downto 21)="011" and addr_valid='1' else '0';
	bank_sel(3) <= '1' when A(23 downto 21)="100" and addr_valid='1' else '0';
	chip_sel(0) <= bank_sel(0) or bank_sel(1);
	chip_sel(1) <= bank_sel(2) or bank_sel(3);
	RAM_SEL <= bank_sel(0) or bank_sel(1) or bank_sel(2) or bank_sel(3);
	
	-- Byte lane decoding (see table 5-7 in 68020 user guide)
	byte_sel(3) <= not A(1) and not A(0);
	byte_sel(2) <= (SIZE(1) or not SIZE(0) or A(0)) and not A(1);
	byte_sel(1) <= (not A(1) or not A(0)) and (SIZE(1) or not SIZE(0) or A(1)) and (not SIZE(1) or SIZE(0) or A(1) or A(0));
	byte_sel(0) <= (SIZE(1) or not SIZE(0) or A(1)) and (SIZE(1) or not SIZE(0) or A(0)) and (not SIZE(0) or A(1) or A(0)) and (not SIZE(1) or SIZE(0) or A(1));
	
	-- Row/column address multiplexing (and output signal to MUX CPLD)
	RAM_A <= A(21 downto 20) when row_enable='1' else A(3 downto 2);
	ROW_MUX <= row_enable;

	
	-- RAM timing (synchronous implementation)
	-- CPU bus cycle states are numbered S0-S5
	-- CPUCLK   H  L  H  L  H  L
	--          0  1  2  3  4  5
	-- nAS      -  0  0  0  0  -
	--
	-- MUX_OUT  0  1  1  0  0  0   (routes ROW address to RAM when high, COL address when low)
	-- nRAS     1  1  0  0  0  0   (when chip_sel asserted)
	-- nCAS     1  1  1  1  0  0   (according to asserted byte enables)
	-- nOE      1  1  0  0  0  0   (read cycles only)
	--
	-- Data must be stable at the end of S4 (for reads)
	process(CLOCK, nRESET)
	begin
		if nRESET = '0' then
			addr_valid_reg <= '0';
			state <= Idle;
			nRAS <= (others => '1');
			nCAS <= (others => '1');
			nOE <= '1';
		elsif rising_edge(CLOCK) then
			-- Register address strobe for edge detection
			addr_valid_reg <= addr_valid;
			
			case state is
				when Idle =>
					if addr_valid='1' and addr_valid_reg='0' then
						-- Start of S2
						-- Assert RAS for selected chip and assert OE for read cycles
						nRAS <= not chip_sel;
						nOE <= not ((chip_sel(0) or chip_sel(1)) and R_nW);
						state <= RASState;
					end if;
				when RASState =>
					-- Start of S4
					-- Assert CAS for selected byte lanes
					nCAS <= not byte_sel;
					state <= CASState;
				when CASState =>
					-- Start of S0
					-- End cycle
					nRAS <= (others => '1');
					nCAS <= (others => '1');
					nOE <= '1';
					state <= Idle;
				when others =>
					null;
			end case;
		end if;
	end process;
	
	-- Delay RAS to next falling edge for row/column select
	process(CLOCK, nRESET)
	begin
		if nRESET = '0' then
			row_enable <= '1';
		elsif falling_edge(CLOCK) then
			row_enable <= chip_sel(0) nor chip_sel(1);
		end if;
	end process;
	
	
end architecture;

