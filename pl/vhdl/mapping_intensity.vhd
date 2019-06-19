----------------------------------------------------------------------------------
-- Company: NovelIC
-- Engineer: Ilija Petkovic
-- 
-- Create Date: 06/05/2019 10:47:23 AM
-- Design Name: 
-- Module Name: mapping_intensity - Behavioral
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
use ieee.numeric_std.all;

library work;
use work.math_real.all;


entity mapping_intensity is

    Generic(
    
        INPUT_BUS_WIDTH : integer := 8;
        OUTPUT_BUS_WIDTH : integer := 8;
        PARAMETER_BUS_WIDTH : integer := 32;
        NUMBER_OF_HISTOGRAM_ELEMENT : integer := 256;
        MAX_NUMBER_OF_PROCESSING_DATA : integer := 100000;
        STATUS_REGISTER_WIDTH : integer := 8;
        CONTROL_REGISTER_WIDTH : integer := 8
    );

	Port (
        reset                  : in  std_logic;
        avs_params_address     : in  std_logic_vector(1 downto 0);
        avs_params_read        : in  std_logic;
        avs_params_readdata    : out std_logic_vector(PARAMETER_BUS_WIDTH - 1 downto 0);
        avs_params_write       : in  std_logic;
        avs_params_writedata   : in  std_logic_vector(PARAMETER_BUS_WIDTH - 1 downto 0);
        avs_params_waitrequest : out std_logic;
        clk                    : in  std_logic;
        
        -- For data
        asi_in_data            : in  std_logic_vector(INPUT_BUS_WIDTH - 1 downto 0);
        asi_in_ready           : out std_logic;
        asi_in_valid           : in  std_logic;
        asi_in_sop             : in  std_logic;
        asi_in_eop             : in  std_logic;
        aso_out_data           : out std_logic_vector(OUTPUT_BUS_WIDTH - 1 downto 0);
        aso_out_ready          : in  std_logic;
        aso_out_valid          : out std_logic;
        aso_out_sop            : out std_logic;
        aso_out_eop            : out std_logic; 
        aso_out_empty          : out std_logic;
        
        -- For configuration
        asi_in_data_conf            : in  std_logic_vector(INPUT_BUS_WIDTH - 1 downto 0);
        asi_in_ready_conf           : out std_logic;
        asi_in_valid_conf           : in  std_logic;
        asi_in_sop_conf             : in  std_logic;
        asi_in_eop_conf             : in  std_logic
 
    );

end mapping_intensity;

architecture Behavioral of mapping_intensity is

    -- Components
    component ram_dual_port is

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
            
    end component;
    
    -- Constants
    -- Address of registers
    constant ADDRESS_OF_CONFIGURATION_REGISTER : std_logic_vector(1 downto 0) := "00";
    constant ADDRESS_OF_STATUS_REGISTER : std_logic_vector(1 downto 0) := "01";
    constant ADDRESS_OF_CONTROL_REGISTER : std_logic_vector(1 downto 0) := "10";
    
    -- Constants
    constant RAM_ADDRESS_WIDTH : integer := integer(ceil(log2(real(NUMBER_OF_HISTOGRAM_ELEMENT))));
    constant WIDTH_OF_CONFIGURATION_REGISTER : integer := integer(ceil(log2(real(MAX_NUMBER_OF_PROCESSING_DATA))));
    
    -- Status register values
    constant CONFIGURED : integer := 0;
    constant MAPPING_CONFIGURED : integer := 1;
    constant CALCULATING : integer := 2;
    constant END_CALC : integer := 3;
    --constant SENDING : integer := 4;
    --constant END_SEND : integer := 5;
    --constant END_CLEAR : integer := 6;
    
    -- Control registers
    constant START_CONF : integer := 0;
    constant START_CALC : integer := 1;
    --constant STOP : integer := 1;
    --constant START_SEND : integer := 2;
    
    
    -- Signals
    
    -- Registers
    signal configuration_register : std_logic_vector(WIDTH_OF_CONFIGURATION_REGISTER - 1 downto 0);
    signal status_register : std_logic_vector(STATUS_REGISTER_WIDTH - 1 downto 0);
    signal control_register : std_logic_vector(CONTROL_REGISTER_WIDTH - 1 downto 0);
    
    -- If is one value in Conf reg can be set on new value
    signal configuration_register_strobe : std_logic;
    -- If is one value in Status reg can be set on new value
    signal status_register_strobe : std_logic;
    -- If is one value in Control reg can be set on new value
    signal control_register_strobe : std_logic;
    
    -- RAM
    
    -- Write port
    signal reg_wr_addr_i : std_logic_vector(RAM_ADDRESS_WIDTH - 1 downto 0);
    signal reg_wr_data_i : std_logic_vector(OUTPUT_BUS_WIDTH - 1 downto 0);
    signal reg_wr_en_i : std_logic;

    -- Read port
    signal reg_rd_addr_i : std_logic_vector(RAM_ADDRESS_WIDTH - 1 downto 0);
    signal reg_rd_data_o : std_logic_vector(OUTPUT_BUS_WIDTH - 1 downto 0);
    signal reg_rd_en_i : std_logic;
    
    -- Custom

    -- Counter data load in component
    signal ram_data_counter : unsigned(WIDTH_OF_CONFIGURATION_REGISTER - 1 downto 0);
    -- Component is configured
    signal configure : std_logic;
    -- Flag for reading value from RAM
    signal read : std_logic_vector(1 downto 0);
    -- Flag for writting value to RAM
    signal written : std_logic_vector(1 downto 0);
    -- If is '1' calculating is over
    signal send : std_logic;
    -- Counter for sending values
    signal counter : unsigned(RAM_ADDRESS_WIDTH downto 0);
    -- Flag for reading value in RAM by sending 
    signal written_out : std_logic_vector(1 downto 0);
    -- Flag for writing value in RAM by sending
    signal read_out : std_logic_vector(1 downto 0);
    -- Counter for clearing RAM
    signal counter_clear : unsigned(RAM_ADDRESS_WIDTH downto 0);
    -- Clear flag for RAM
    signal clear : std_logic;
    
    signal configured_value_flag : std_logic;
    
    signal last : std_logic;



begin


    RAM_label : ram_dual_port generic map (RAM_ADDR_WIDTH_G => RAM_ADDRESS_WIDTH,
                                           RAM_DATA_WIDTH_G => OUTPUT_BUS_WIDTH)
                                port map(reg_wr_addr_i => reg_wr_addr_i,
                                         reg_wr_data_i => reg_wr_data_i,
                                         reg_wr_en_i => reg_wr_en_i,
                                         reg_rd_addr_i => reg_rd_addr_i,
                                         reg_rd_data_o => reg_rd_data_o, 
                                         reg_rd_en_i => reg_rd_en_i,
                                         clk => clk 
                                         );
   
    -- Writing registers strobs
    configuration_register_strobe <= '1' when (avs_params_address = ADDRESS_OF_CONFIGURATION_REGISTER) and (avs_params_write = '1') else '0';
    status_register_strobe <= '1' when (avs_params_address = ADDRESS_OF_STATUS_REGISTER) and (avs_params_read = '1') else '0';
    control_register_strobe <= '1' when (avs_params_address = ADDRESS_OF_CONTROL_REGISTER) and (avs_params_write = '1') else '0';
    
    sequential_process : process(clk) is
    begin
    
        if(rising_edge(clk)) then
        
            if(reset = '1') then
            
                control_register <= (others => '0');
                status_register <= (others => '0');
                configuration_register <= (others => '0');
                reg_wr_addr_i <= (others => '0');
                reg_wr_data_i <= (others => '0');
                reg_wr_en_i <= '0';
                reg_rd_en_i <= '0';
                counter <= (others => '0');
                configured_value_flag <= '0';
                ram_data_counter <= (others => '0');
                last <= '0';
                read <= (others => '0');
                aso_out_valid <= '0';
                aso_out_data <= (others => '0');
                written <= (others => '0');
					 asi_in_ready <= '0';
					 --reg_rd_data_o <= (others => '0');
            
            else
        
                -- Loading configutration
                if(configuration_register_strobe =  '1') then
                    configuration_register <= avs_params_writedata(WIDTH_OF_CONFIGURATION_REGISTER - 1 downto 0);
                    -- Component is configured
                    status_register(CONFIGURED) <= '1';
						  status_register(END_CALC) <= '0';
                end if;
                
                -- Loading control
                if(control_register_strobe =  '1') then
                    control_register <= avs_params_writedata(CONTROL_REGISTER_WIDTH - 1 downto 0); 
                end if; 
                
                -- Reading status
                if(status_register_strobe =  '1') then
                    avs_params_readdata(STATUS_REGISTER_WIDTH - 1 downto 0) <= status_register;    
                end if;
                
                if(status_register(CONFIGURED) = '1' and control_register(START_CONF) = '1' and configured_value_flag = '0' and status_register(MAPPING_CONFIGURED) = '0') then

                    reg_wr_en_i <= '1';
                    counter <= (others => '0');
                    configured_value_flag <= '1';      
                    asi_in_ready_conf <= '1';  
                    last <= '0';
                    read <= "00";   
                
                end if;
                
                if(configured_value_flag = '1' and status_register(MAPPING_CONFIGURED) = '0') then
                
                    if(asi_in_valid_conf = '1') then
                        counter <= counter + 1;
                        reg_wr_addr_i <= std_logic_vector(counter(reg_wr_addr_i'length - 1 downto 0));
                        reg_wr_data_i <= asi_in_data_conf;
                        
                        if(counter = NUMBER_OF_HISTOGRAM_ELEMENT - 1) then
                        
                            asi_in_ready_conf <= '0';
                            status_register(MAPPING_CONFIGURED) <= '1';
                            counter <= (others => '0');
                            written <= "01";
                        
                        end if;
                        
                    end if;
                
                end if;
                
                if(written = "01") then
                
                    written <= "10";
                    reg_wr_en_i <= '0';
						  read <= "00";
                
                end if;
					 
                
					 asi_in_ready <= '0';
					 
					 aso_out_valid <= '0';
					 
                if(status_register(MAPPING_CONFIGURED) = '1' and control_register(START_CALC) = '1' and written = "10") then
                
                    status_register(CALCULATING) <= '1';

                
                    if(asi_in_valid = '1' and read = "00") then

								  asi_in_ready <= '1';
								  read <= "01";
								  reg_rd_addr_i <= asi_in_data;
								  reg_rd_en_i <= '1';							   
                    
                    end if;
						  
						  if(read = "01") then
						  
								read <= "10"; 
						  
						  end if;
						  
						  if(read = "10") then
						  
								aso_out_valid <= '1';
								reg_rd_en_i <= '0';
								aso_out_data <= reg_rd_data_o;
								read <= "11";
						  
						  end if;
						  
						  if(read = "11") then
						  
							  aso_out_valid <= '1';
							  --aso_out_data <= reg_rd_data_o;
						  
							  if(aso_out_ready = '1') then
									
										ram_data_counter <= ram_data_counter + 1;
										--aso_out_data <= reg_rd_data_o;
										read <= "00";
										aso_out_valid <= '0';
									
							  end if;
							  
						  end if;
                    
                    if(ram_data_counter = to_integer(unsigned(configuration_register))) then
                    
                        last <= '1';
                        asi_in_ready <= '0';
								aso_out_valid <= '0';
								status_register(CALCULATING) <= '0';
                    
                    end if;
                    
                end if;
                
                
                if(aso_out_ready = '1' and last = '1') then
                 
                    status_register(END_CALC) <= '1';
                    status_register(CONFIGURED) <= '0';
                    status_register(MAPPING_CONFIGURED) <= '0';
                    configured_value_flag <= '0';
                    written <= (others => '0');
                    ram_data_counter <= (others => '0');
                    reg_rd_en_i <= '0';
                    read <= "00";
						  aso_out_valid <= '0';
						  
                
                end if;
                
                
                
            end if;
            
        end if; 
    
    end process sequential_process;

    
    aso_out_sop <= '0';
    aso_out_eop <= '0';
    aso_out_empty <= '0';



end Behavioral;
