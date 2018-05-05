--
--  K1208 Mux CPLD Logic (Xilinx XC9536XL)
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
--  K1208 Mux CPLD all functionality
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity k1208_mux is
port (
	CLKCPU		:	in 		std_logic;
	JUMPER		:	in		std_logic;
	RAM_MUX		:	in		std_logic;
	A			:	in		std_logic_vector (19 downto 3);
	RAM_A		:	out		std_logic_vector (9 downto 2);
	IPL			:	out		std_logic_vector (2 downto 0)
	);
end entity;

architecture rtl of k1208_mux is
begin
	IPL <= (others => 'Z');		-- not used
	
	-- This CPLD is just a simple address mux for RAS/CAS
	RAM_A <= A(19 downto 12) when RAM_MUX='1' else A(11 downto 4);
end architecture;

