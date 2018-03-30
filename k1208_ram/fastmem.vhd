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
generic(
	-- CPU ticks between refresh cycles
	REFRESH_INTERVAL	:	positive	:= 200 - 1
	);
port (
	CLOCK		:	in		std_logic;
	nRESET		:	in		std_logic;
	
	R_nW		:	in		std_logic;
	nAS			:	in		std_logic;
	A			:	in		std_logic_vector(23 downto 0);
	SIZE		:	in		std_logic_vector(1 downto 0);

	EIGHT_MEG	:	in		std_logic;  -- enables upper 4MB if asserted
	SELECTED	:	out		std_logic;	-- RAM region is addressed (async)
	READY		:	out		std_logic;	-- RAM is ready (sync)

	ROW_MUX		:	out		std_logic; -- selects row address
	RAM_A		:	out		std_logic_vector(1 downto 0);
	nOE			:	out		std_logic;
	nRAS		:	out		std_logic_vector(1 downto 0);
	nCAS		:	out		std_logic_vector(3 downto 0)
	);
end entity;

architecture rtl of fastmem is
type state_t is (Idle, RASState, CASState, CBR1, CBR2);
signal state		:		state_t;
signal addr_valid	:		std_logic;
signal addr_valid_reg	:	std_logic;
signal bank_sel		:		std_logic_vector(3 downto 0);
signal chip_sel		:		std_logic_vector(1 downto 0);
signal ram_sel		:		std_logic;
signal byte_sel		:		std_logic_vector(3 downto 0);
signal row_enable	:		std_logic;
signal rcounter		:		unsigned(7 downto 0);
signal refresh_req	:		std_logic;
begin
	-- Address decoding
	addr_valid <= nRESET and not nAS;
	bank_sel(0) <= '1' when A(23 downto 21)="001" and addr_valid='1' else '0';
	bank_sel(1) <= '1' when A(23 downto 21)="010" and addr_valid='1' else '0';
	bank_sel(2) <= '1' when A(23 downto 21)="011" and addr_valid='1' and EIGHT_MEG='1' else '0';
	bank_sel(3) <= '1' when A(23 downto 21)="100" and addr_valid='1' and EIGHT_MEG='1' else '0';
	chip_sel(0) <= bank_sel(0) or bank_sel(1);
	chip_sel(1) <= bank_sel(2) or bank_sel(3);
	ram_sel <= chip_sel(0) or chip_sel(1);
	SELECTED <= ram_sel;
	
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
		if nRESET='0' then
			state <= Idle;
			nRAS <= (others => '1');
			nCAS <= (others => '1');
			nOE <= '1';
			READY <= '0';
			rcounter <= (others => '0');
			refresh_req <= '0';
			addr_valid_reg <= '0';
		elsif rising_edge(CLOCK) then
			rcounter <= rcounter + 1;
			
			-- Trigger per-row CBR refresh
			if rcounter = REFRESH_INTERVAL then
				rcounter <= (others => '0');
				refresh_req <= '1';
			end if;
			
			-- Register address strobe for edge detection (detect start of machine cycle)
			addr_valid_reg <= addr_valid;
			
			case state is
				when Idle =>
					-- *** NOTE ***
					-- Some (but not all) DRAM datasheets call for /WE to be high
					-- when /RAS is asserted during a CBR refresh cycle.  We do not
					-- guarantee this here (which yields a small performance gain), and
					-- it does not seem to affect stability, but this may need to be revisited.
					-- An improved solution would be to gate RAM /WE via the CPLD rather than
					-- connecting it directly to R/W.
					--if refresh_req = '1' then
					-- NOTE2: Disabling the above for stability comparison. This is slower but guarantees
					-- /WE will be high during refresh.
					if refresh_req='1' and addr_valid='1' and addr_valid_reg='0' and R_nW='1' then
						-- Insert a refresh cycle
						nCAS <= (others => '0');
						refresh_req <= '0';
						state <= CBR1;
					elsif addr_valid='1' and ram_sel='1' then
						-- Assert RAS for selected chip and OE for read cycles
						nRAS <= not chip_sel;
						nOE <= not R_nW;
						READY <= '1';
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
					READY <= '0';
					state <= Idle;
				when CBR1 =>
					nRAS <= (others => '0');
					state <= CBR2;
				when CBR2 =>
					nRAS <= (others => '1');
					nCAS <= (others => '1');
					state <= Idle;
				when others =>
					null;
			end case;
		end if;
	end process;
	
	-- Delay RAS to next falling edge for row/column select
	process(CLOCK, nRESET)
	begin
		if nRESET='0' then
			row_enable <= '1';
		elsif falling_edge(CLOCK) then
			if state=RASState then
				-- CAS is next - output column address
				row_enable <= '0';
			else
				-- Output row address by default
				row_enable <= '1';
			end if;
		end if;
	end process;
	
	
end architecture;

