----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2024/12/13 10:25:49
-- Design Name: 
-- Module Name: sysref_trig_det - Behavioral
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

entity sysref_trig_det is
port (
--   rst                   : in std_logic; 
   pl_sysref             : in std_logic;
   clk_125               : in std_logic;
   clk_625               : in std_logic;
   clk_adc               : in std_logic;
   trans_ena_625         : out std_logic := '0';
   trans_ena_625_check   : out std_logic := '0';
   trans_ena_125_dbg     : out std_logic := '0';
   trans_ena_adc         : out std_logic := '0';
   waitsysref            : out std_logic := '0'
);
end sysref_trig_det;

architecture Behavioral of sysref_trig_det is

signal cnt64                 : std_logic_vector(63 downto 0)    := (others => '0');
signal pl_sysref_d1          : std_logic                         := '0';
signal pl_sysref_d2          : std_logic                         := '0';
signal pl_sysref_d3          : std_logic                         := '0';
signal wait_for_sysref       : std_logic                         := '0';
signal trans_ena             : std_logic                         := '0';
signal trans_ena_d1          : std_logic                         := '0';
signal trans_ena_125         : std_logic                         := '0';
signal pulse_width_cnt_flag  : std_logic                         := '0';
signal rst_n                 : std_logic                         ;
signal trans_ena_625_tmp     : std_logic                         := '0';
signal trans_ena_625_tmp_d1  : std_logic                         := '0';
signal trans_ena_625_tmp_d2  : std_logic                         := '0';
signal trans_ena_625_tmp_d3  : std_logic                         := '0';

signal trans_ena_625_chk_d1  : std_logic                         := '0';
signal trans_ena_625_chk_d2  : std_logic                         := '0';
signal trans_ena_625_chk_d3  : std_logic                         := '0';

--��Ƶ�Ӵ򿪵��رռ���
signal dc_pluse_cnt          : std_logic_vector(63 downto 0)    := (others => '0');

--���������ȼ���
signal pulse_width_cnt       : std_logic_vector(15 downto 0)    := (others => '0');

signal pulse_width_cnt_max   : std_logic_vector(15 downto 0)    := (others => '0');
signal pulse_width_cnt_min   : std_logic_vector(15 downto 0)    := (others => '1');

signal trans_ena_adc_tmp     : std_logic                        := '0';

attribute mark_debug : string;
attribute keep       : string;

attribute mark_debug of cnt64                   : signal is "true";
attribute mark_debug of pl_sysref_d1            : signal is "true";
attribute mark_debug of pl_sysref_d2            : signal is "true";
attribute mark_debug of pl_sysref_d3            : signal is "true";
attribute mark_debug of wait_for_sysref         : signal is "true";
attribute mark_debug of trans_ena_125           : signal is "true";
attribute mark_debug of trans_ena               : signal is "true";
attribute mark_debug of rst_n                   : signal is "true";
attribute mark_debug of dc_pluse_cnt            : signal is "true";
attribute mark_debug of pulse_width_cnt         : signal is "true";
attribute mark_debug of pulse_width_cnt_max     : signal is "true";
attribute mark_debug of pulse_width_cnt_min     : signal is "true";
attribute mark_debug of pulse_width_cnt_flag    : signal is "true";                        
                        
attribute keep       of cnt64                   : signal is "true";
attribute keep       of pl_sysref_d1            : signal is "true";
attribute keep       of pl_sysref_d2            : signal is "true";
attribute keep       of pl_sysref_d3            : signal is "true";
attribute keep       of wait_for_sysref         : signal is "true";
attribute keep       of trans_ena_125           : signal is "true";
attribute keep       of trans_ena               : signal is "true";
attribute keep       of rst_n                   : signal is "true";
attribute keep       of dc_pluse_cnt            : signal is "true";
attribute keep       of pulse_width_cnt         : signal is "true";
attribute keep       of pulse_width_cnt_max     : signal is "true";
attribute keep       of pulse_width_cnt_min     : signal is "true";
attribute keep       of pulse_width_cnt_flag    : signal is "true";         

COMPONENT fifo_generator_0 is
  PORT (
    rst : IN STD_LOGIC;
    wr_clk : IN STD_LOGIC;
    rd_clk : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC
  );
END COMPONENT;

begin

process(clk_125)
begin
    if clk_125'event and clk_125 = '0' then
        pl_sysref_d1     <= pl_sysref;
        pl_sysref_d2     <= pl_sysref_d1;
        pl_sysref_d3     <= pl_sysref_d2;
    end if;
end process;

process(clk_125)
begin
    if clk_125'event and clk_125 = '1' then
        cnt64            <= cnt64 + 1;
        trans_ena_d1     <= trans_ena;
        trans_ena_125_dbg <= trans_ena_125;
--        rst_n <= NOT rst;
        
        if pl_sysref_d2 = '1' and pl_sysref_d3 = '0' then
            pulse_width_cnt_flag  <= '1';
        elsif pl_sysref_d2 = '0' and pl_sysref_d3 = '1' then
            pulse_width_cnt_flag  <= '0';
        end if;
        
        if pulse_width_cnt_flag = '1' then
            pulse_width_cnt   <= pulse_width_cnt + 1;
        else
            pulse_width_cnt   <= (others => '0' );
        end if;
        
        if unsigned(pulse_width_cnt) > 7 then
            cnt64    <= (others => '0');
        end if;
        
        
        if unsigned(cnt64(41 downto 10)) > 610351 then
            wait_for_sysref    <= '1';
            waitsysref         <= '1';
        end if;
        
        if wait_for_sysref = '1' then
            if pl_sysref_d2 = '1' and pl_sysref_d3 = '0' then
                pulse_width_cnt_flag  <= '1';
                dc_pluse_cnt    <= dc_pluse_cnt + 1;
            elsif pl_sysref_d2 = '0' and pl_sysref_d3 = '1' then
                pulse_width_cnt_flag  <= '0';    
            end if;
            
            if pulse_width_cnt_flag = '1' then
                pulse_width_cnt   <= pulse_width_cnt + 1;
            else
                pulse_width_cnt   <= (others => '0' );
            end if;
            
            if unsigned(pulse_width_cnt) > 7 then
                trans_ena       <= '1';
            end if;              
            
--            if unsigned(pulse_width_cnt) > 50 then
--                trans_ena       <= '1';
--            end if;
            
--            if unsigned(pulse_width_cnt) > 12 then
--                dc_pluse_cnt    <= dc_pluse_cnt + 1;
--            end if;
                            
--            if unsigned(pulse_width_cnt) > unsigned(pulse_width_cnt_max) then
--                pulse_width_cnt_max    <= pulse_width_cnt;
--            end if;
            
--            if unsigned(pulse_width_cnt) < unsigned(pulse_width_cnt_min) then
--                pulse_width_cnt_min    <= pulse_width_cnt;
--            end if;
            

            
            if trans_ena = '1' and trans_ena_d1 = '0' then
                trans_ena_125    <= '1';
                trans_ena_625    <= '1';
                trans_ena_adc    <= '1';
            else 
                trans_ena_125 <= '0';
            end if;
            
            
            
        end if;
        
    end if;
    
end process;

--fifo_1 : fifo_generator_0
--  PORT MAP (
--    rst    => rst_n,
--    wr_clk => clk_125,
--    rd_clk => clk_625,
--    din    => "1",
--    wr_en  => trans_ena_125,
--    rd_en  => '1',
--    dout(0) => trans_ena_625_tmp
--  );
  
  
--fifo_2 : fifo_generator_0
--  PORT MAP (
--    rst    => rst_n,
--    wr_clk => clk_125,
--    rd_clk => clk_adc,
--    din    => "1",
--    wr_en  => trans_ena_125,
--    rd_en  => '1',
--    dout(0) => trans_ena_adc_tmp
--  );  
  
--process(clk_625)
--begin
--    if clk_625'event and clk_625 = '1' then
--        trans_ena_625_tmp_d1    <= trans_ena_625_tmp;
--        trans_ena_625_tmp_d2    <= trans_ena_625_tmp_d1;
--        trans_ena_625_tmp_d3    <= trans_ena_625_tmp_d2;
        
--        if trans_ena_625_tmp_d3 = '1' then
--            trans_ena_625           <= '1';
--        end if;
        
--        trans_ena_625_chk_d1    <= trans_ena_625_tmp;
--        trans_ena_625_chk_d2    <= trans_ena_625_chk_d1;
--        trans_ena_625_chk_d3    <= trans_ena_625_chk_d2;
--        trans_ena_625_check     <= trans_ena_625_chk_d3;
        
--    end if;
--end process;


--process(clk_adc, rst)
--begin
--    if rst = '0' then
--        trans_ena_adc     <= '0';
--    elsif clk_adc'event and clk_adc = '1' then
--        if trans_ena_adc_tmp = '1' then
--            trans_ena_adc    <= '1';
--        end if;   
--    end if;
--end process;



end Behavioral;




