----------------------------------------------------------------------------------
-- Company: NovelIC
-- Engineer: Ilija Petkovic
-- 
-- Create Date: 06/28/2018 02:14:42 PM
-- Design Name: ram_dual_port
-- Module Name: ram_dual_port - Behavioral
-- Project Name: FFT - RADIX2
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
use ieee.numeric_std.all;



entity ram_dual_port is

    generic(
            -- Specify RAM data and address widths
            RAM_ADDR_WIDTH_G : integer := 8;
            RAM_DATA_WIDTH_G : integer := 19
            );
    port(
        -- Clock
        clk : in std_logic;
    
        -- Write port
        reg_wr_addr_i : in std_logic_vector(RAM_ADDR_WIDTH_G-1 downto 0);
        reg_wr_data_i : in std_logic_vector(RAM_DATA_WIDTH_G-1 downto 0);
        reg_wr_en_i : in std_logic;
    
        -- Read port
        reg_rd_addr_i : in  std_logic_vector(RAM_ADDR_WIDTH_G-1 downto 0);
        reg_rd_data_o : out std_logic_vector(RAM_DATA_WIDTH_G-1 downto 0);
        reg_rd_en_i : in  std_logic
        );
            
end ram_dual_port;



architecture Behavioral of ram_dual_port is

    -- define RAM type
    type ram_type is array (2**RAM_ADDR_WIDTH_G-1 downto 0) of std_logic_vector (RAM_DATA_WIDTH_G-1 downto 0);
    
    -- Define RAM registers
    signal reg_s : ram_type := (others => (others => '0'));

begin

    -- Register write and read
    process(clk)
    begin
    
        if(rising_edge(clk)) then

           -- Read
            if(reg_wr_en_i = '1') then
                reg_s(to_integer(unsigned(reg_wr_addr_i))) <= reg_wr_data_i;
            end if;
            
            -- Write
            if(reg_rd_en_i = '1') then
                reg_rd_data_o <= reg_s(to_integer(unsigned(reg_rd_addr_i)));
            end if;
                    
         end if;
        
    end process;


end Behavioral;
