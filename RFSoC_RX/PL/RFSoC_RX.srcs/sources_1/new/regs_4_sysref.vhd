----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12/23/2025 08:04:45 AM
-- Design Name: 
-- Module Name: regs_4_sysref - Behavioral
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
use ieee.STD_LOGIC_1164.ALL;
use ieee.std_logic_signed.all;
use ieee.numeric_std.all;
library work; 


-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity regs_4_sysref is
port (
    clk               : in std_logic;
    sysref_adc        : in std_logic;
    sysref_dac        : in std_logic;
    reg_sysref_adc    : out std_logic;
    reg_sysref_dac    : out std_logic
);
end regs_4_sysref;

architecture Behavioral of regs_4_sysref is

signal reg_adc          : std_logic_vector(15 downto 0)    := (others => '0');
signal reg_dac          : std_logic_vector(15 downto 0)    := (others => '0');

begin

process(clk)
begin
    if clk'event and clk = '1' then
        for n in 0 to 14 loop
            reg_adc(n+1)    <= reg_adc(n);
            reg_dac(n+1)    <= reg_dac(n);
        end loop;
        reg_adc(0)     <= sysref_adc;
        reg_dac(0)     <= sysref_dac;
        reg_sysref_adc    <= reg_adc(15);
        reg_sysref_dac    <= reg_dac(15);
    end if;
end process;


end Behavioral;
