----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    22:15:28 03/22/2018 
-- Design Name: 
-- Module Name:    k1208_mux - rtl 
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

entity k1208_mux is
port (
	CLKCPU		: in 		std_logic;
	JUMPER		: in		std_logic;
	RAM_MUX	: in		std_logic;
	A					: in		std_logic_vector (19 downto 3);
	RAM_A			: out		std_logic_vector (9 downto 2);
	IPL				: out		std_logic_vector (2 downto 0)
	);
end entity;

architecture rtl of k1208_mux is
begin
	RAM_A <= (others => '0');
	IPL <= (others => 'Z');
end architecture;

