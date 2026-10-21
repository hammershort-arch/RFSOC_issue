----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/22/2024 06:34:32 AM
-- Design Name: 
-- Module Name: daq_timing_ctrl - Behavioral
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


entity daq_timing_ctrl is
port (
    clk_adc          : in std_logic;
    clk_eth          : in std_logic;
    eth_info_valid   : in std_logic;
    sig1             : in std_logic;
    storage_ena      : out std_logic  := '0'
);
end daq_timing_ctrl;

architecture Behavioral of daq_timing_ctrl is



signal cnt64                        : std_logic_vector(63 downto 0)     := (others => '0');
signal sig1_d1                      : std_logic                         := '0';
signal sig1_d2                      : std_logic                         := '0';
signal sig1_d3                      : std_logic                         := '0';
signal sig1_d4                      : std_logic                         := '0';
signal eth_info_valid_cdc           : std_logic                         := '0';  
signal eth_info_valid_pulse         : std_logic                         := '0';
signal eth_info_valid_d1            : std_logic                         := '0';
type daq_state_type is (IDLE, WAIT_SIG1, STORAGE);
signal daq_state                    : daq_state_type                    := IDLE;

component onebit_cdc_fifo IS
  PORT (
    wr_clk : IN STD_LOGIC;
    rd_clk : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC;
    valid : OUT STD_LOGIC
  );
END component;


component bit16_cdc_fifo IS
  PORT (
    wr_clk : IN STD_LOGIC;
    rd_clk : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC;
    valid : OUT STD_LOGIC
  );
END component;


component bit32_cdc_fifo IS
  PORT (
    wr_clk : IN STD_LOGIC;
    rd_clk : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC;
    valid : OUT STD_LOGIC
  );
END component;


component vio_cal_sel is
port(
    clk                 : in std_logic;
    probe_out0          : out std_logic_vector(0 downto 0)
);
end component;




COMPONENT bit64_cdc_fifo
  PORT (
    wr_clk : IN STD_LOGIC;
    rd_clk : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC;
    valid : OUT STD_LOGIC
  );
END COMPONENT;


attribute mark_debug : string;
attribute keep       : string;


attribute mark_debug of sig1_d4                    : signal is "true";
attribute keep       of sig1_d4                    : signal is "true";


attribute mark_debug of daq_state                  : signal is "true";
attribute keep       of daq_state                  : signal is "true";


attribute mark_debug of eth_info_valid_cdc         : signal is "true";
attribute keep       of eth_info_valid_cdc         : signal is "true";




begin


u_onebit_cdc_fifo_eth_valid: onebit_cdc_fifo
port map(
    wr_clk      => clk_eth,
    rd_clk      => clk_adc,
    din         => "0",
    wr_en       => eth_info_valid_pulse,
    rd_en       => '1',
    valid       => eth_info_valid_cdc
);


process(clk_eth)
begin
    if clk_eth'event and clk_eth = '1' then
        eth_info_valid_d1       <= eth_info_valid;
        if eth_info_valid = '1' and eth_info_valid_d1 = '0' then
            eth_info_valid_pulse    <= '1';
        else
            eth_info_valid_pulse    <= '0';
        end if;
    end if;
end process;


process(clk_adc)
begin
    if clk_adc'event and clk_adc = '1' then
        sig1_d1           <= sig1;
        sig1_d2           <= sig1_d1;
        sig1_d3           <= sig1_d2;
        sig1_d4           <= sig1_d3;
        case daq_state is
            when IDLE        => 
                if eth_info_valid_cdc = '1' then
                    daq_state       <= WAIT_SIG1;
                end if;
            when WAIT_SIG1   =>
                 cnt64       <= (others => '0');
                 if sig1_d3 = '1' and sig1_d4 = '0' then
                     daq_state       <= STORAGE;
                 end if;
            when STORAGE        => 
                 storage_ena  <= '1';
                 cnt64    <= cnt64 + 1;
                 if unsigned(cnt64) = 2047 then  --add more 100 cycles to avoid jumping to TRANSMIT state too early, since transit length is controlled in clk_adc domain 
                     daq_state           <= IDLE;
                     cnt64               <= (others => '0');
                     storage_ena         <= '0';
                 end if;
        end case;
        
    end if;
end process;

end Behavioral;
