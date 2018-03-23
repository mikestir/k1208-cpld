----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    22:15:28 03/22/2018 
-- Design Name: 
-- Module Name:    k1208_ram - rtl 
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

entity k1208_ram is
port (
	CLKCPU		:	in 		std_logic;
	nRESET		:	in		std_logic;
	
	-- CPU bus
	-- Address bus has some holes in it so we concatenate the parts explicitly
	-- to avoid undefined behaviour of the unmapped bits
	AH			:	in		std_logic_vector(23 downto 15);
	AM			:	in		std_logic_vector(13 downto 12);
	AL			:	in		std_logic_vector(6 downto 0);
	D			:	inout	std_logic_vector(31 downto 24);
	nDS			:	in		std_logic;
	nAS			:	in		std_logic;
	R_nW		:	in		std_logic;
	SIZ			:	in		std_logic_vector(1 downto 0);
	nDSACK		:	out		std_logic_vector(1 downto 0);
	nINT2		:	out		std_logic;
	nOVR		:	in		std_logic;
	
	-- RAM
	RAM_MUX		:	out		std_logic;
	RAM_A		:	out		std_logic_vector(1 downto 0);
	RAM_nOE		:	out		std_logic;
	RAM_nRAS	:	out		std_logic_vector(1 downto 0);
	RAM_nCAS	:	out		std_logic_vector(3 downto 0);
	
	-- IO/SPI
	SPI_SCLK	:	out		std_logic;
	SPI_MOSI	:	out		std_logic;
	SPI_MISO	:	in		std_logic;
	SPI_nCS		:	out		std_logic
	);
end entity;

architecture rtl of k1208_ram is
signal A	:	std_logic_vector(23 downto 0);
begin
	-- Derive full address bus
	A <= AH & "0" & AM & "00000" & AL;

	SPI_SCLK <= '0';
	SPI_MOSI <= '0';
	SPI_nCS <= '0';
	RAM_MUX <= '0';
	RAM_A <= (others => '0');
	RAM_nOE <= '1';
	RAM_nRAS <= (others => '1');
	RAM_nCAS <= (others => '1');
	
	nDSACK <= (others => 'Z');
	nINT2 <= 'Z';
	
	D <= (others => 'Z');
	
end architecture;

