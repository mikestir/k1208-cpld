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
--  Implementation of Amiga Zorra 2 auto-configuration
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity autoconfig is
generic (
	Z2_TYPE		:	std_logic_vector(7 downto 0)	:= X"C0";
	Z2_FLAGS	:	std_logic_vector(7 downto 0)	:= X"80";
	Z2_PROD		:	integer	:= 0;
	Z2_MFG		:	integer	:= 12345
	);
port (
	CLOCK		:	in	std_logic;
	nRESET		:	in	std_logic;
	
	-- Region size may be varied in the logic
	SIZE		:	in	std_logic_vector(2 downto 0);
	
	CONFIG_IN	:	in	std_logic;
	CONFIG_OUT	:	out	std_logic;
	
	ENABLE		:	in	std_logic;
	WR			:	in	std_logic;
	A			:	in std_logic_vector(6 downto 0);
	D_IN		:	in	std_logic_vector(3 downto 0);
	D_OUT		:	out	std_logic_vector(3 downto 0)
	);
end entity;

architecture rtl of autoconfig is
constant z2_type_val	:	std_logic_vector(7 downto 0)	:= Z2_TYPE;
constant z2_flags_val	:	std_logic_vector(7 downto 0)	:= not Z2_FLAGS;
constant z2_prod_val	:	std_logic_vector(7 downto 0)	:= not std_logic_vector(to_unsigned(Z2_PROD, 8));
constant z2_mfg_val		:	std_logic_vector(15 downto 0)	:= not std_logic_vector(to_unsigned(Z2_MFG, 16));

signal configured		:	std_logic;
signal selected			:	std_logic;
signal read_reg			:	std_logic_vector(3 downto 0);
-- Using the stored base address makes the design too large for the XC9572, but
-- as long as we don't use it the fitter will optimise it away.
signal base				:	std_logic_vector(15 downto 0);
begin
	selected <= CONFIG_IN and not configured;
	CONFIG_OUT <= configured;
	
	-- Zorro registers are 16-bits wide in memory so addresses increment in 2s
	-- 128 bytes are decoded (odd bytes are empty and lower nibbles of even bytes are empty)
	-- All but the first byte are inverted
	with "0" & A select
		read_reg <=
			z2_type_val(7 downto 4) when X"00", -- type
			z2_type_val(3 downto 3) & SIZE when X"02",
			z2_prod_val(7 downto 4) when X"04", -- product
			z2_prod_val(3 downto 0) when X"06",
			z2_flags_val(7 downto 4) when X"08", -- flags
			z2_flags_val(3 downto 0) when X"0A",
			X"F" when X"0C", -- reserved
			X"F" when X"0D",
			z2_mfg_val(15 downto 12) when X"10", -- mfg high
			z2_mfg_val(11 downto 8) when X"12",
			z2_mfg_val(7 downto 4) when X"14", -- mfg low
			z2_mfg_val(3 downto 0) when X"16",
			--
			X"F" when others;
	
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

	write_cycle: process(CLOCK,nRESET)
	begin
		if nRESET='0' then
			configured <= '0';
			base <= (others => '0');
		elsif rising_edge(CLOCK) and ENABLE='1' and WR='1' and selected='1' then
			-- Amiga will write the configuration address registers in order
			-- 46, 44, 4a, 48.  The board is configured once 48 has been
			-- written.  See http://amigadev.elowar.com/read/ADCD_2.1/Hardware_Manual_guide/node02C8.html
			case "0" & A is
				when X"44" =>
					base(15 downto 12) <= D_IN;
				when X"46" =>
					base(11 downto 8) <= D_IN;
				when X"48" =>
					base(7 downto 4) <= D_IN;
					configured <= '1'; -- configured
				when X"2A" =>
					base(3 downto 0) <= D_IN;
				when others =>
					null;
			end case;
		end if;
	end process;
end architecture;

