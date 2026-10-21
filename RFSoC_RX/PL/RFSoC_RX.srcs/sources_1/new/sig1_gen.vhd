----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12/18/2024 04:41:52 AM
-- Design Name: 
-- Module Name: sig1_gen - Behavioral
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

entity sig1_gen is
port (
     clk            : in std_logic;
     trans_ena_0    : in std_logic;
     sig1           : out std_logic 
);
end sig1_gen;

architecture Behavioral of sig1_gen is

signal cnt          : std_logic_vector(31 downto 0)    := (others => '0');

begin

process(clk)
begin
    if clk'event and clk = '1' then
        if trans_ena_0 = '1' then
            cnt    <= cnt + 1;
            if unsigned(cnt) = 80000000 then
                sig1       <= '1';
            elsif unsigned(cnt) = 0 then
                sig1       <= '0';
            end if;
            
            if unsigned(cnt) = 160000000 - 1 then
                cnt        <= (others => '0');
            end if;
        else
            cnt        <= (others => '0');
        end if;
        
    end if; 
end process;

end Behavioral;
