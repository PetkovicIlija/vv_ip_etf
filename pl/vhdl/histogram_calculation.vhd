----------------------------------------------------------------------------------
-- Company: NovelIC
-- Engineer: Ilija Petkovic
-- 
-- Create Date: 05/18/2019 01:17:55 PM
-- Design Name: 
-- Module Name: histogram_calculation - Behavioral
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


entity histogram_calculation is

    Generic(
    
        INPUT_BUS_WIDTH : integer := 8;
        OUTPUT_BUS_WIDTH : integer := 32;
        PARAMETER_BUS_WIDTH : integer := 32;
        NUMBER_OF_HISTOGRAM_ELEMENT : integer := 256;
        MAX_NUMBER_OF_PROCESSING_DATA : integer := 100000;
        STATUS_REGISTER_WIDTH : integer := 8;
        CONTROL_REGISTER_WIDTH : integer := 8
    );

	Port (
    reset                  : in  std_logic                     := '0';             --  reset.reset
    avs_params_address     : in  std_logic_vector(1 downto 0)                     := "00";             -- params.address
    avs_params_read        : in  std_logic                     := '0';             --       .read
    avs_params_readdata    : out std_logic_vector(PARAMETER_BUS_WIDTH - 1 downto 0);                     --       .readdata
    avs_params_write       : in  std_logic                     := '0';             --       .write
    avs_params_writedata   : in  std_logic_vector(PARAMETER_BUS_WIDTH - 1 downto 0)  := (others => '0'); --       .writedata
    avs_params_waitrequest : out std_logic;                                        --       .waitrequest
    clk                    : in  std_logic                     := '0';             --  clock.clk
    asi_in_data            : in  std_logic_vector(INPUT_BUS_WIDTH - 1 downto 0)  := (others => '0'); --     in.data
    asi_in_ready           : out std_logic;                                        --       .ready
    asi_in_valid           : in  std_logic                     := '0';             --       .valid
    asi_in_sop             : in  std_logic                     := '0';             --       .startofpacket
    asi_in_eop             : in  std_logic                     := '0';             --       .endofpacket
    aso_out_data           : out std_logic_vector(OUTPUT_BUS_WIDTH - 1 downto 0);                    --    out.data
    aso_out_ready          : in  std_logic                     := '0';             --       .ready
    aso_out_valid          : out std_logic;                                        --       .valid
    aso_out_sop            : out std_logic;                                        --       .startofpacket
    aso_out_eop            : out std_logic;                                        --       .endofpacket
    aso_out_empty          : out std_logic_vector(1 downto 0)                                         --       .empty
    );
    
end histogram_calculation;

architecture Behavioral of histogram_calculation is

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
    constant CALCULATING : integer := 1;
    constant END_CALC : integer := 2;
    constant SENDING : integer := 3;
    constant END_SEND : integer := 4;
    constant END_CLEAR : integer := 5;
    
    -- Control registers
    constant START_CALC : integer := 0;
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
    signal ram_data_counter : unsigned(OUTPUT_BUS_WIDTH - 1 downto 0);
    -- Component is configured
    signal configure : std_logic;
    -- Flag for reading value from RAM
    signal read : std_logic_vector(1 downto 0);
    -- Flag for writting value to RAM
    signal written : std_logic_vector(0 downto 0);
    -- If is '1' calculating is over
    signal send : std_logic;
    -- Counter for sending values
    signal counter_out : unsigned(RAM_ADDRESS_WIDTH downto 0);
    -- Flag for reading value in RAM by sending 
    signal written_out : std_logic_vector(1 downto 0);
    -- Flag for writing value in RAM by sending
    signal read_out : std_logic_vector(1 downto 0);
    -- Counter for clearing RAM
    signal counter_clear : unsigned(RAM_ADDRESS_WIDTH downto 0);
    -- Clear flag for RAM
    signal clear : std_logic;

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
            
                configuration_register <= (others => '0');
                control_register <= (others => '0');
                status_register <= (others => '0');
                ram_data_counter <= (others => '0');
                asi_in_ready <= '0';
                read <= (others => '0');
                written <= (others => '0');
                reg_wr_addr_i <= (others => '0');
                reg_wr_data_i <= (others => '0');
                reg_wr_en_i <= '0';
                reg_rd_addr_i <= (others => '0');
                reg_rd_en_i <= '0';
                send <= '0';
                counter_out <= (others => '0');
                written_out <= (others => '0');
                read_out <= (others => '0');
                aso_out_valid <= '0';
                --aso_out_data <= (others => '0');
                counter_clear <= (others => '0');
                clear <= '0';
            
            else
            
                -- Loading configutration
                if(configuration_register_strobe =  '1') then
                    configuration_register <= avs_params_writedata(WIDTH_OF_CONFIGURATION_REGISTER - 1 downto 0);
                    -- Component is configured
                    status_register(CONFIGURED) <= '1';
                    status_register(END_CLEAR) <= '0';
                    send  <= '0';
                end if;
                
                -- Loading control
                if(control_register_strobe =  '1') then
                    control_register <= avs_params_writedata(CONTROL_REGISTER_WIDTH - 1 downto 0); 
                end if; 
                
                -- Reading status
                if(status_register_strobe =  '1') then
                    avs_params_readdata(STATUS_REGISTER_WIDTH - 1 downto 0) <= status_register;    
                end if;  
                
                --aso_out_data <= reg_rd_data_o; 
                
                if(control_register(START_CALC) = '1' and status_register(CONFIGURED) = '1' and clear = '0') then
                
                    asi_in_ready <= '1';
                
                    if(asi_in_valid = '1' and send  = '0' and clear = '0' and read = "00") then       
                
                        asi_in_ready <= '0';
                        
                        status_register(CALCULATING) <= '1';
                        
								--if(read = "00") then
								read <= "01";
								--end if;
                        
                        reg_rd_en_i <= '1';
                        reg_rd_addr_i <= asi_in_data;
                        
                    end if;                       
                            
                    if(read = "01") then 
                        
                            read <= "10"; 
                            reg_wr_en_i <= '1';
                            reg_wr_addr_i <= reg_rd_addr_i;
                            asi_in_ready <= '0';
                    end if;
                    
                    if(read = "10") then
                        
                            asi_in_ready <= '0';
                            reg_rd_en_i <= '0';
                            
                            case(written) is
                            
                                when("0") =>
                                    reg_wr_data_i <= std_logic_vector(unsigned(reg_rd_data_o) + 1);
                                    written <= (others => '1');
                                when others =>
                                    read <= (others => '0');
                                    written <= (others => '0');
                                    reg_wr_en_i <= '0';
                                    asi_in_ready <= '1';
                                    ram_data_counter <= ram_data_counter + 1;
                                    --if(ram_data_counter = unsigned(configuration_register) - 1) then
                                    --    send  <= '1';
                                    --    status_register(END_CALC) <= '1';
                                    --    asi_in_ready <= '0';
                                    --end if;
                            
                            end case;
                    
                    end if; 

						  if(asi_in_eop = '1') then
								 send  <= '1';
								 status_register(END_CALC) <= '1';
								 asi_in_ready <= '0';
						  end if;					
				  
					 end if; 
                
                if(send = '1' and clear = '0') then
                
						  if(counter_out < 2) then
								--reg_rd_addr_i <= std_logic_vector(counter_out(RAM_ADDRESS_WIDTH - 1 downto 0) - 2);
						  --else
								reg_rd_addr_i <= (others => '0');
						  end if;
                    
                    if(read_out = "00") then
                        reg_rd_en_i <= '1';
                        read_out <= "01";
                    end if;
                                
                    if(read_out = "01") then 
                            read_out <= "10"; 
                            counter_out <= counter_out + 1;
                    end if;
                    
                    if(read_out = "10") then
                            
                            aso_out_valid <= '1';
                            
                            if(aso_out_ready = '1') then
                            
                                counter_out <= counter_out + 1;
										  if(counter_out > 1) then
												reg_rd_addr_i <= std_logic_vector(unsigned(reg_rd_addr_i) + 1);
										  end if;
                            
                            end if;

                    end if;
                    
                    if(counter_out = NUMBER_OF_HISTOGRAM_ELEMENT + 2) then
						  --asi_in_eop
						  --if(asi_in_eop = '1') then
                        send  <= '0';
                        clear <= '1';
                        aso_out_valid <= '0';
                        read_out <= (others => '0');
                        counter_out <= (others => '0');
                        status_register(END_SEND) <= '1';
                    end if;
                
                end if;
                
                if(clear = '1') then
                
                    reg_wr_addr_i <= std_logic_vector(counter_clear(RAM_ADDRESS_WIDTH - 1 downto 0));
                    reg_wr_data_i <= (others => '0');
                
                    if(written_out = "00") then
                        reg_wr_en_i <= '1';
                        written_out <= "01";
                    end if;
                                
                    if(written_out = "01") then 
                            written_out <= "10"; 
                            counter_clear <= counter_clear + 1;
                    end if;
                    
                    if(written_out = "10") then

                        counter_clear <= counter_clear + 1;
    
                    end if;
                    
                    if(counter_clear = NUMBER_OF_HISTOGRAM_ELEMENT) then
                        clear <= '0';
                        status_register(END_CLEAR) <= '1';
                        status_register(END_SEND) <= '0';
                        status_register(CONFIGURED) <= '0';
                        status_register(CALCULATING) <= '0';
                        status_register(END_CALC) <= '0';
                        status_register(SENDING) <= '0';
								--configuration_register <= (others => '0');
								--control_register <= (others => '0');
                        control_register <= (others => '0');
                        written_out <= (others => '0');
                        counter_clear <= (others => '0');
								ram_data_counter <= (others => '0');
								reg_wr_addr_i <= (others => '0');
								reg_wr_data_i <= (others => '0');
								reg_wr_en_i <= '0';
								reg_rd_addr_i <= (others => '0');
								reg_rd_en_i <= '0';
								counter_out <= (others => '0');
                    end if;
               
                end if;       
            
            end if;
               
        end if;

    end process;
    
    avs_params_waitrequest <= '0';
    aso_out_sop <= '0';
    aso_out_eop <= '0';
    aso_out_empty <= (others => '0');
    aso_out_data <= reg_rd_data_o;

end Behavioral;

