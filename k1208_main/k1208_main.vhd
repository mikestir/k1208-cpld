----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    22:15:28 03/22/2018 
-- Design Name: 
-- Module Name:    k1208_main - rtl 
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

entity k1208_main is
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
	
	-- SD SPI
	SD_nCS		:	out		std_logic;
	SD_SCLK		:	out		std_logic;
	SD_MOSI		:	out		std_logic;
	SD_MISO		:	in		std_logic;
	
	-- NET/EXP SPI
	SPI_nCS0	:	out		std_logic;
	SPI_nCS1	:	out		std_logic;
	SPI_SCLK	:	out		std_logic;
	SPI_MOSI	:	out		std_logic;
	SPI_MISO	:	in		std_logic;
	
	-- NET
	NET_nRESET	:	out		std_logic;
	NET_nINT	:	in		std_logic;
	
	-- GPIO (header)
	GPIO		:	inout	std_logic_vector(9 downto 0);
	
	-- 4MB/8MB jumper
	n4MB		:	in		std_logic
	);
end entity;

architecture rtl of k1208_main is

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
end component;

signal a			:	std_logic_vector(23 downto 0);
signal d_in			:	std_logic_vector(7 downto 0);
signal d_out_z2_ram	:	std_logic_vector(3 downto 0);
signal d_out_z2_io	:	std_logic_vector(3 downto 0);
signal d_out_spi1	:	std_logic_vector(7 downto 0);
signal d_out_spi2	:	std_logic_vector(7 downto 0);
signal rd			:	std_logic;
signal wr			:	std_logic;

-- Chip selects
signal autoconf_sel	:	std_logic; -- E80000-E90000
signal io_sel		:	std_logic; -- E90000-EA0000
signal spi1_sel		:	std_logic; -- E90000-E9007F
signal spi2_sel		:	std_logic; -- E91000-E9107F
signal addr_valid	:	std_logic;

-- Auto config
signal eight_meg	:	std_logic;
signal ram_size		:	std_logic_vector(2 downto 0);
signal config_out	:	std_logic_vector(1 downto 0);

-- RAM timing
signal ram_sel		:	std_logic;
signal ram_ready	:	std_logic;

-- SPI
signal spi1_busy	:	std_logic;
signal spi2_busy	:	std_logic;
signal spi1_ncs_all	:	std_logic_vector(1 downto 0);
signal spi2_ncs_all	:	std_logic_vector(1 downto 0);
signal spi2_int		:	std_logic;
begin
	-- Instantiate autoconfig instance for RAM function
	autoconfig_ram: autoconfig
		generic map (
			Z2_TYPE => X"e8", -- RAM board, next function is related
			Z2_FLAGS => X"c0"
		)
		port map (
			CLKCPU, nRESET,
			ram_size,
			'1', config_out(0),
			autoconf_sel, wr, a(6 downto 0), d_in(7 downto 4), d_out_z2_ram
		);
	ram_size <= "000" when eight_meg='1' else "111"; -- Select 4MB or 8MB fastmem region
	
	-- Instantiate autoconfig instance for IO function (SPI/NET/GPIO)
	autoconfig_io: autoconfig
		generic map (
			Z2_TYPE => X"c1", -- IO board
			Z2_FLAGS => X"40"
		)
		port map (
			CLKCPU, nRESET,
			"001", -- 64 KB
			config_out(0), config_out(1),
			autoconf_sel, wr, a(6 downto 0), d_in(7 downto 4), d_out_z2_io
		);
		
	-- Instantiate RAM controller
	fastmem_inst: fastmem
		port map (
			CLKCPU, nRESET,
			R_nW, nAS, A, SIZ,
			eight_meg,
			ram_sel, ram_ready,
			RAM_MUX, RAM_A, RAM_nOE, RAM_nRAS, RAM_nCAS
		);
		
	-- Instantiate SD card SPI interface
	spi1_inst: spi
		port map (
			CLKCPU, nRESET,
			spi1_sel, wr, a(3 downto 2), d_in, d_out_spi1, spi1_busy, 
			'1', open,
			spi1_ncs_all, SD_SCLK, SD_MOSI, SD_MISO
		);
	SD_nCS <= spi1_ncs_all(0);

	-- Instantiate expansion SPI interface
	spi2_inst: spi
		port map (
			CLKCPU, nRESET,
			spi2_sel, wr, a(3 downto 2), d_in, d_out_spi2, spi2_busy, 
			NET_nINT, spi2_int,
			spi2_ncs_all, SPI_SCLK, SPI_MOSI, SPI_MISO
		);
	SPI_nCS0 <= spi2_ncs_all(0);
	SPI_nCS1 <= spi2_ncs_all(1);
	
	NET_nRESET <= '1';
	
	-- Derive full address bus with holes filled
	a <= AH & "0" & AM & "00000" & AL;
	
	-- Route data bus
	rd <= R_nW and not nDS;
	wr <= not R_nW and not nDS;
	d_in <= D;
	D <= d_out_z2_ram & "1111" when rd='1' and autoconf_sel='1' and config_out="00" else
		d_out_z2_io & "1111" when rd='1' and autoconf_sel='1' and config_out="01" else
		d_out_spi1 when rd='1' and spi1_sel='1' else
		d_out_spi2 when rd='1' and spi2_sel='1' else
		(others => 'Z');
	
	-- Decode function selects
	addr_valid <= nRESET and not nAS;
	autoconf_sel <= '1' when A(23 downto 16)=X"E8" and addr_valid='1' else '0';
	io_sel <= '1' when A(23 downto 16)=X"E9" and addr_valid='1' else '0';
	spi1_sel <= io_sel and not A(12);
	spi2_sel <= io_sel and A(12);
	
	-- nDSACK="10" for 8-bit cycles (IO) and "00" for 32-bit cycles (RAM)
	nDSACK(0) <= '0' when autoconf_sel='1' or (spi1_sel='1' and spi1_busy='0') or (spi2_sel='1' and spi2_busy='0') or ram_ready='1' else 'Z';
	nDSACK(1) <= '0' when ram_ready='1' else 'Z';

	-- /OVR needs to be asserted prior to the CPU asserting /AS
	-- (see http://www.ianstedman.co.uk/downloads/A1200FuncSpec.txt)
	-- This prevents the Amiga from internally generating DSACK signals for
	-- the memory areas that we are managing.
	nOVR <= '0' when autoconf_sel='1' or io_sel='1' or ram_sel='1' else 'Z';
	
	-- External interrupt from network interface gated to EXT2
	nINT2 <= '0' when spi2_int='1' else 'Z';
	
	-- Register 4MB/8MB jumper and lock after autoconfig has started
	process(CLKCPU, nRESET)
	begin
		if nRESET='0' then
			eight_meg <= '0';
		elsif rising_edge(CLKCPU) and config_out="00" then
			eight_meg <= n4MB;
		end if;
	end process;
end architecture;

