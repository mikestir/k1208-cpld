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
	nOVR		:	out		std_logic;
	
	-- RAM
	RAM_MUX		:	out		std_logic;
	RAM_A		:	out		std_logic_vector(1 downto 0);
	RAM_nOE		:	out		std_logic;
	RAM_nRAS	:	out		std_logic_vector(1 downto 0);
	RAM_nCAS	:	out		std_logic_vector(3 downto 0);
	
	-- IO/SPI
	SPI_nCS		:	out		std_logic;
	SPI_SCLK	:	out		std_logic;
	SPI_MOSI	:	out		std_logic;
	SPI_MISO	:	in		std_logic
	);
end entity;

architecture rtl of k1208_ram is

component autoconfig is
generic (
	Z2_TYPE		:	std_logic_vector(7 downto 0)	:= X"C0";
	Z2_FLAGS	:	std_logic_vector(7 downto 0)	:= X"80";
	Z2_PROD		:	integer	:= 0;
	Z2_MFG		:	integer	:= 12345
	);
port (
	CLOCK		:	in	std_logic;
	nRESET		:	in	std_logic;
	
	CONFIG_IN	:	in	std_logic;
	CONFIG_OUT	:	out	std_logic;
	
	ENABLE		:	in	std_logic;
	WR			:	in	std_logic;
	A			:	in std_logic_vector(6 downto 0);
	D_IN		:	in	std_logic_vector(3 downto 0);
	D_OUT		:	out	std_logic_vector(3 downto 0)
	);
end component;

component fastmem is
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
end component;

component spi is
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
end component;

signal a			:	std_logic_vector(23 downto 0);
signal d_in			:	std_logic_vector(7 downto 0);
signal d_out_z2_ram	:	std_logic_vector(3 downto 0);
signal d_out_z2_io	:	std_logic_vector(3 downto 0);
signal d_out_spi	:	std_logic_vector(7 downto 0);
signal rd			:	std_logic;
signal wr			:	std_logic;

-- Chip selects
signal autoconf_sel	:	std_logic; -- E80000-E90000
signal io_sel		:	std_logic; -- E90000-EA0000
signal addr_valid	:	std_logic;

-- Auto config
signal config_out	:	std_logic_vector(1 downto 0);

-- RAM timing
signal ram_sel		:	std_logic;
signal ram_ready	:	std_logic;

-- SPI
signal spi_ncs_all	:	std_logic_vector(3 downto 0);
begin
	-- Instantiate autoconfig instance for RAM function
	autoconfig_ram: autoconfig
		generic map (
			--Z2_TYPE => X"e0", -- 8MB
			Z2_TYPE => X"e7", -- 4MB
			Z2_FLAGS => X"c0"
		)
		port map (
			CLKCPU, nRESET,
			'1', config_out(0),
			autoconf_sel, wr, a(6 downto 0), d_in(7 downto 4), d_out_z2_ram
		);
	
	-- Instantiate autoconfig instance for IO function
	autoconfig_io: autoconfig
		generic map (
			Z2_TYPE => X"c1", -- 64KB
			Z2_FLAGS => X"40"
		)
		port map (
			CLKCPU, nRESET,
			config_out(0), config_out(1),
			autoconf_sel, wr, a(6 downto 0), d_in(7 downto 4), d_out_z2_io
		);
		
	-- Instantiate RAM controller
	fastmem_inst: fastmem
		port map (
			CLKCPU, nRESET,
			R_nW, nAS, A, SIZ,
			'0', -- 0 = 4MB, 1 = 8MB
			ram_sel, ram_ready,
			RAM_MUX, RAM_A, RAM_nOE, RAM_nRAS, RAM_nCAS
		);
		
	-- Instantiate SPI controller
	spi_inst: spi
		port map (
			CLKCPU, nRESET,
			io_sel, wr, a(3 downto 2), d_in, d_out_spi,
			spi_ncs_all, SPI_SCLK, SPI_MOSI, SPI_MISO
		);
	SPI_nCS <= spi_ncs_all(0);
	
	-- Derive full address bus with holes filled
	a <= AH & "0" & AM & "00000" & AL;
	
	-- Route data bus
	rd <= R_nW and not nDS;
	wr <= not R_nW and not nDS;
	d_in <= D;
	D <= d_out_z2_ram & "1111" when rd='1' and autoconf_sel='1' and config_out="00" else
		d_out_z2_io & "1111" when rd='1' and autoconf_sel='1' and config_out="01" else
		d_out_spi when rd='1' and io_sel='1' else
		(others => 'Z');
	
	-- Decode function selects
	addr_valid <= nRESET and not nAS;
	autoconf_sel <= '1' when A(23 downto 16)=X"E8" and addr_valid='1' else '0';
	io_sel <= '1' when A(23 downto 16)=X"E9" and addr_valid='1' else '0';
	
	-- nDSACK="10" for 8-bit cycles (IO) and "00" for 32-bit cycles (RAM)
	nDSACK(0) <= '0' when autoconf_sel='1' or io_sel='1' or ram_ready='1' else 'Z';
	nDSACK(1) <= '0' when ram_ready='1' else 'Z';

	-- /OVR needs to be asserted prior to the CPU asserting /AS
	-- (see http://www.ianstedman.co.uk/downloads/A1200FuncSpec.txt)
	-- But maybe it isn't needed in expansion card space as it seems
	-- to work fine without it.
	-- This was tested by inserting dummy delays to hold off DSACK assertion in RAM and
	-- observing that the machine performance reduced.  Also, not asserting DSACK does cause
	-- the machine to hang as would be expected.
	nOVR <= 'Z';
	
	-- Unused outputs
	nINT2 <= 'Z';
end architecture;

