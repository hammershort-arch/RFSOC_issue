----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12/22/2025 02:45:13 PM
-- Design Name: 
-- Module Name: sync_out_latch - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
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
use ieee.std_logic_signed.all;
use ieee.numeric_std.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity sync_out_latch is
port (
    clk              : in std_logic;
    sync             : in std_logic;
    waitforsysref    : in std_logic;
    sync_reg         : out std_logic  := '0' 
);
end sync_out_latch;

architecture Behavioral of sync_out_latch is

signal waitforsysref_d1      : std_logic             := '0';
signal waitforsysref_d2      : std_logic             := '0';
signal waitforsysref_d3      : std_logic             := '0';
signal waitforsysref_d4      : std_logic             := '0';

begin

process(clk)
begin
    if clk'event and clk = '1' then
        waitforsysref_d1           <= waitforsysref;
        waitforsysref_d2           <= waitforsysref_d1;
        waitforsysref_d3           <= waitforsysref_d2;
        waitforsysref_d4           <= waitforsysref_d3;
        if sync = '1' and waitforsysref_d4 = '1' then
            sync_reg     <= '1';
        end if;
    end if;
end process;


end Behavioral;
