
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library work;
use work.math_real.all;



entity histogram_calc is

    Generic(
    
        INPUT_BUS_WIDTH : integer := 8;
        OUTPUT_BUS_WIDTH : integer := 32;
        PARAMETER_BUS_WIDTH : integer := 32;
        NUMBER_OF_HISTOGRAM_ELEMENT : real := 256.0;
        MAX_NUMBER_OF_PROCESSING_DATA : real := 100000.0 ;
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
    aso_out_empty          : out std_logic                                         --       .empty
);

end histogram_calc;

architecture Behavioral of histogram_calc is

    -- Address of registers
    constant ADDRESS_OF_CONFIGURATION_REGISTER : std_logic_vector(1 downto 0) := "00";
    constant ADDRESS_OF_STATUS_REGISTER : std_logic_vector(1 downto 0) := "01";
    constant ADDRESS_OF_CONTROL_REGISTER : std_logic_vector(1 downto 0) := "10";
    
    -- Constants
    constant RAM_ADDRESS_WIDTH : integer := integer(ceil(log2(NUMBER_OF_HISTOGRAM_ELEMENT)));
    constant WIDTH_OF_CONFIGURATION_REGISTER : integer := integer(ceil(log2(MAX_NUMBER_OF_PROCESSING_DATA)));

    -- Registers
    signal configuration_register : std_logic_vector(WIDTH_OF_CONFIGURATION_REGISTER - 1 downto 0);
    signal status_register : std_logic_vector(STATUS_REGISTER_WIDTH - 1 downto 0);
    signal control_register : std_logic_vector(CONTROL_REGISTER_WIDTH - 1 downto 0);
    
    -- Status register values
    constant CALCULATING : integer := 0;
    constant END_CALC : integer := 1;
    constant SENDING : integer := 2;
    constant END_SEND : integer := 3;
    
    -- Control registers
    constant START_CALC : integer := 0;
    constant STOP : integer := 1;
    constant START_SEND : integer := 2;
    
    -- Component
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
    
    type state_machine is (idle, processing, read_first_second_on_way, read_first_only, write_first_on_way, write_first_on_way_read_new_first_on_way, second_was_read_first_is_written,first_is_written_second_was_read_new_first_is_read, send);
    
    -- Signals
    
    -- If is one value in Conf reg can be set on new value
    signal configuration_register_strobe : std_logic;
    -- If is one value in Status reg can be set on new value
    signal status_register_strobe : std_logic;
    -- If is one value in Control reg can be set on new value
    signal control_register_strobe : std_logic;
    -- State machine register
    signal state_reg : state_machine;
    
    -- RAM's signals
    -- Write port
    signal reg_wr_addr_i : std_logic_vector(RAM_ADDRESS_WIDTH-1 downto 0);
    signal reg_wr_data_i : std_logic_vector(OUTPUT_BUS_WIDTH-1 downto 0);
    signal reg_wr_en_i : std_logic;
    -- Read port
    signal reg_rd_addr_i : std_logic_vector(RAM_ADDRESS_WIDTH-1 downto 0);
    signal reg_rd_data_o : std_logic_vector(OUTPUT_BUS_WIDTH-1 downto 0);
    signal reg_rd_en_i : std_logic;
    
    --Counter which count input data, data depends of number in configuration register
    signal ram_data_counter : unsigned(WIDTH_OF_CONFIGURATION_REGISTER-1 downto 0);
    -- Flags which means new using of RAM, if member of ram_reset_flags is '0' that means field in RAM has value 0
    signal ram_reset_flags : std_logic_vector(integer(NUMBER_OF_HISTOGRAM_ELEMENT)-1 downto 0);
    -- If is '1' that means start of salculating a histogram
    signal start_flag : std_logic;
    signal control_flag : std_logic;
    signal config_flag : std_logic;
    -- Latching value of configuration register
    signal config_reg : std_logic_vector(WIDTH_OF_CONFIGURATION_REGISTER - 1 downto 0);
    -- Latching value of control register
    signal cont_reg : std_logic_vector(CONTROL_REGISTER_WIDTH - 1 downto 0);
    -- Latching inputs value "FIRST" data
    signal tmp_asi_in_data_1 : std_logic_vector(INPUT_BUS_WIDTH - 1 downto 0);
    -- Latching inputs value "SECOND" data
    signal tmp_asi_in_data_2 : std_logic_vector(INPUT_BUS_WIDTH - 1 downto 0);
    -- Latching inputs value "THIRD" data
    signal tmp_asi_in_data_3 : std_logic_vector(INPUT_BUS_WIDTH - 1 downto 0);
    -- Latching read value form RAM - "FIRST"
    signal tmp_reg_wr_data_i_1 : unsigned(OUTPUT_BUS_WIDTH-1 downto 0);
    -- Latching read value form RAM - "SECOND"
    signal tmp_reg_wr_data_i_2 : unsigned(OUTPUT_BUS_WIDTH-1 downto 0);
        -- Latching read value form RAM - "SECOND"
    signal tmp_reg_wr_data_i_3 : unsigned(OUTPUT_BUS_WIDTH-1 downto 0);
    -- If is one means that current and last input data are same
    signal flag_duplicate : std_logic;
    -- Counter which counts sent data
    signal counter : unsigned(RAM_ADDRESS_WIDTH downto 0);
    -- Latching read value form RAM - "SECOND"
    signal tmp_reg_wr_data_i : std_logic_vector(OUTPUT_BUS_WIDTH-1 downto 0);
    
    signal tmp_reg_wr_data_i_1_0_1 : std_logic_vector(OUTPUT_BUS_WIDTH+1 downto 0);
    -- If is '1' that means loaded last data
    signal last : std_logic;
    -- Counter of clock for waiting in 'send' state
    signal delay : unsigned(2 downto 0);
    

begin

    -- RAM Instantion
    ram_dual_port_inst : ram_dual_port 
        generic map (RAM_ADDR_WIDTH_G => RAM_ADDRESS_WIDTH,
                    RAM_DATA_WIDTH_G => OUTPUT_BUS_WIDTH)
            port map (reg_wr_addr_i => reg_wr_addr_i,
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
    
            -- Reset value
            if(reset = '0') then
            
                ram_reset_flags <= (others => '0');
                state_reg <= idle;
                start_flag <= '0';
                control_flag <= '0';
                config_reg <= (others => '0');
                status_register <= (others => '0');
                configuration_register <= (others => '0');
                control_register <= (others => '0');
                status_register <= (others => '0');
                config_flag <= '0';
                ram_data_counter <= (others => '0');
                flag_duplicate <= '0';
                counter <= (others => '0');
                last <= '0';
                delay <= (others => '0');
                reg_wr_addr_i <= (others => '0');
                reg_wr_data_i <= (others => '0');
                reg_wr_en_i <= '0';
                reg_rd_addr_i <= (others => '0');
                reg_rd_en_i <= '0';
                tmp_asi_in_data_1 <= (others => '0');
                tmp_asi_in_data_2 <= (others => '0');
                tmp_asi_in_data_3 <= (others => '0');
                tmp_reg_wr_data_i_1 <= (others => '0');
                tmp_reg_wr_data_i_2 <= (others => '0');
                tmp_reg_wr_data_i_3 <= (others => '0');
                tmp_reg_wr_data_i <= (others => '0');
                tmp_reg_wr_data_i_1_0_1 <= (others => '0');
                aso_out_sop <= '0';
                aso_out_eop <= '0';
                    
            else
            
                -- Loading configutration
                if(configuration_register_strobe =  '1') then
                    configuration_register <= avs_params_writedata(WIDTH_OF_CONFIGURATION_REGISTER - 1 downto 0);
                end if;
                
                -- Loading control
                if(control_register_strobe =  '1') then
                    control_register <= avs_params_writedata(CONTROL_REGISTER_WIDTH - 1 downto 0); 
                end if; 
                
                -- Reading status
                if(status_register_strobe =  '1') then
                    avs_params_readdata(STATUS_REGISTER_WIDTH - 1 downto 0) <= status_register;    
                end if;    
            
                -- !!!!!!!!!!!!!!!!!!
                case(state_reg) is
                
                    -- Reset state
                    -- If valid = '1' arrived address for "FIRST" data,
                    -- Reading RAM on address for "FIRST"
                    when idle =>
                        
                         -- Reset signals
                         aso_out_sop <= '0';
                         aso_out_eop <= '0';
                         reg_rd_en_i <= '0';
                         reg_wr_en_i <= '0';
                        
                         -- If is valid and if that is start of packet
                         aso_out_valid <= '0';
                         -- Going to next state
                         -- First case when packet is start
                         -- Second when packet is not over and new data arrived
                         if(((asi_in_valid = '1' and asi_in_sop = '1' and ram_data_counter = 0) or (ram_data_counter /= 0 and asi_in_valid = '1')) and last = '0') then
                         
                            -- Pripering for reading "FIRST"
                            reg_rd_addr_i <= asi_in_data;
                            -- Enable RAM for reading
                            reg_rd_en_i <= '1';
                            -- Next state
                            state_reg <= processing;
                            -- Latch address for "FIRST" 
                            tmp_asi_in_data_1 <= asi_in_data;
                            -- Inc 
                            ram_data_counter <= ram_data_counter + 1;
                                      
                         end if;
                     
                     -- "FIRST" data is reading
                     -- If data is valid pripering for reading "SECOND"
                     when processing =>
                     
                        if(asi_in_valid = '1' and last = '0') then
                     
                            -- "SECOND" data       
                            reg_rd_addr_i <= asi_in_data;
                            -- Next state 
                            state_reg <= read_first_second_on_way;
                            -- Inc
                            ram_data_counter <= ram_data_counter + 1;
                            -- Latchong address for "SECOND"
                            tmp_asi_in_data_2 <= asi_in_data;
                            -- All data are processed
                            if(ram_data_counter = to_integer(unsigned(configuration_register)) - 2 and asi_in_eop = '1') then
                            
                                -- Reset flags
                                ram_data_counter <= (others => '0');
                                -- Next state
                                state_reg <= send;
                                -- Not ready
                                asi_in_ready <= '0';                               
                                -- Loaded last data
                                last <= '1';
                                -- End of calculation
                                status_register(END_CALC) <= '1';
                            
                            end if; 
                            
                        else
                            -- If data is not valid, continuing with processing with "FIRST" only
                            state_reg <= read_first_only;
                            
                        end if;
                     
                     -- "FIRST" was read, writing is started
                     -- If data on input is valid then it is preparing for reading new "FIRST" data          
                     when read_first_only =>  
                     
                        -- Enabling "write" for RAM
                        reg_wr_en_i <= '1';
                        -- Address for writing
                        reg_wr_addr_i <= tmp_asi_in_data_1;
                        -- If is '0' - first reading
                        if(ram_reset_flags(to_integer(unsigned(tmp_asi_in_data_1))) = '0') then
                            -- Write '1'
                            reg_wr_data_i <= std_logic_vector(to_unsigned(1,OUTPUT_BUS_WIDTH));
                            -- Set fleg
                            ram_reset_flags(to_integer(unsigned(tmp_asi_in_data_1))) <= '1'; 
                            -- Latching data new "FIRST"
                            tmp_reg_wr_data_i_1 <= to_unsigned(1,OUTPUT_BUS_WIDTH);   
                        else
                            reg_wr_data_i <= std_logic_vector(unsigned(unsigned(tmp_reg_wr_data_i) + 1));
                            -- Latching data  new "FIRST"
                            tmp_reg_wr_data_i_1 <= unsigned(tmp_reg_wr_data_i) + 1;                 
                        end if;
                                                          
                        -- Preparing for reading a new "FIRST"                                  
                        if(asi_in_valid = '1' and last = '0') then
                            -- Preparing for reading
                            reg_rd_addr_i <= asi_in_data;
                            -- Latching address for new "FIRST"
                            tmp_asi_in_data_2 <= asi_in_data;
                            -- Next state 
                            state_reg <= write_first_on_way_read_new_first_on_way;
                            -- Inc
                            ram_data_counter <= ram_data_counter + 1;
                            if(ram_data_counter = to_integer(unsigned(configuration_register)) - 2 and asi_in_eop = '1') then
                                -- Reset flags
                                ram_data_counter <= (others => '0');
                                -- Next state
                                state_reg <= send;
                                -- Not ready
                                asi_in_ready <= '0';
                                -- Last data in package loaded
                                last <= '1';
                                -- End of calculation
                                status_register(END_CALC) <= '1';
                            end if;
                        else
                            
                            -- If data is not valid write "FIRST" only
                            state_reg <= write_first_on_way;
                            
                        end if;
                        
                     -- Writing "FIRST"   
                     when write_first_on_way =>   

                        -- Disable writing
                        reg_wr_en_i <= '0';
                        -- New "FIRST" is preparing for reading
                        if(asi_in_valid = '1' and last = '0')  then
                            -- Reading address
                            reg_rd_addr_i <= asi_in_data;
                            -- Enable reading
                            reg_rd_en_i <= '1';
                            -- Next state
                            state_reg <= processing; 
                            -- Latching address for reading of "FIRST"
                            tmp_asi_in_data_1 <= asi_in_data;
                            if(ram_data_counter = to_integer(unsigned(configuration_register)) - 2 and asi_in_eop = '1') then
                            
                                -- Reset flags
                                ram_data_counter <= (others => '0');
                                -- Next state
                                state_reg <= send;
                                -- Not ready
                                asi_in_ready <= '0';
                                -- Last data read
                                last <= '1';
                                -- End of calculation
                                status_register(END_CALC) <= '1';
                            
                            end if;
                            
                            
                        else
                            -- If data is not valid next state is "idle"
                            state_reg <= idle;
                        end if;          
                    
                     -- Writing of first is in progress
                     -- New reading of "FIRST" is in progress
                     when write_first_on_way_read_new_first_on_way =>
                        -- Disable writing
                        reg_wr_en_i <= '0';
                        -- Preparing for reading "SECOND"
                        if(asi_in_valid = '1' and last = '0') then
                            reg_rd_addr_i <= asi_in_data; 
                            state_reg <= read_first_second_on_way;
                            -- Inc
                            ram_data_counter <= ram_data_counter + 1;
                            -- Latching address for "FIRST" 
                            tmp_asi_in_data_2 <= asi_in_data;
                            if(ram_data_counter = to_integer(unsigned(configuration_register)) - 1 and asi_in_eop = '1') then
                            
                                -- Reset flags
                                ram_data_counter <= (others => '0');
                                -- Next state
                                state_reg <= send;
                                -- Not ready
                                asi_in_ready <= '0';
                                -- Last data read
                                last <= '1';
                                -- End of calculation
                                status_register(END_CALC) <= '1';
                            
                            end if; 
                         
                        else
                            
                            -- If data is not valid next state is read_first_only
                            -- just reading new "FIRST" data
                            state_reg <= read_first_only;  
                                                                 
                            -- If addresses are same  "FIRST" and  new "FIRST"                                                      
                            if(tmp_asi_in_data_1 = tmp_asi_in_data_2) then
                            
                                -- Data which is written increment for 1
                                tmp_reg_wr_data_i <= std_logic_vector(tmp_reg_wr_data_i_1 + 1);
                            
                            end if;
                            
                            
                        end if;
                     -- Data from 'FIRST' memory location was read
                     -- Data from 'SECOND' memory location is read   
                     when read_first_second_on_way => 
                     
                        -- Rnable writing
                        reg_wr_en_i <= '1';
                        -- Enable writing first
                        reg_wr_addr_i <= tmp_asi_in_data_1;
                        -- If is '0' - first time writing
                        if(ram_reset_flags(to_integer(unsigned(tmp_asi_in_data_1))) = '0') then
                            -- Write '1'
                            reg_wr_data_i <= std_logic_vector(to_unsigned(1,OUTPUT_BUS_WIDTH));
                            -- Latch value for next operation 
                            tmp_reg_wr_data_i_1 <= to_unsigned(1,OUTPUT_BUS_WIDTH);
                            -- Set flags
                            ram_reset_flags(to_integer(unsigned(tmp_asi_in_data_1))) <= '1';    
                        else
                            -- Incerement for one more same data
                            reg_wr_data_i <= std_logic_vector(unsigned(unsigned(tmp_reg_wr_data_i) + 1)); 
                            -- Latching data - new value of  "FIRST"
                            tmp_reg_wr_data_i_1 <= unsigned(unsigned(tmp_reg_wr_data_i) + 1);                 
                        end if;
                        
                        -- If data is valid                               
                        if(asi_in_valid = '1' and last = '0') then
                            -- Address for new "FIRST"
                            reg_rd_addr_i <= asi_in_data;
                            -- Next state 
                            state_reg <= first_is_written_second_was_read_new_first_is_read;
                            -- Inc
                            ram_data_counter <= ram_data_counter + 1;
                            -- Latching address for new "FIRST"
                            tmp_asi_in_data_3 <= asi_in_data;
                            if(ram_data_counter = to_integer(unsigned(configuration_register)) - 1 and asi_in_eop = '1') then
                            
                                -- Reset flags
                                ram_data_counter <= (others => '0');
                                -- Next state
                                state_reg <= send;
                                -- Not ready
                                asi_in_ready <= '0';
                                -- Last data read
                                last <= '1';
                                -- End of calculation
                                status_register(END_CALC) <= '1';

                            end if;
                        else
                            -- If valid is '0'
                            state_reg <= second_was_read_first_is_written;                            
                            
                        end if; 
                        -- If addresses are same  "FIRST" and  "SECOND"                                                      
                        if(tmp_asi_in_data_2 = tmp_asi_in_data_1) then
                        
                            -- Data which is written increment for 1
                            tmp_reg_wr_data_i <= std_logic_vector(unsigned(tmp_reg_wr_data_i) + 1);
                        
                        else
                        
                            -- Latch read data
                            tmp_reg_wr_data_i <= reg_rd_data_o;
                        
                        end if;  
                     -- Data is written on 'FIRST' memory location 
                     -- Data from 'SECOND' memory location was read                        
                     when second_was_read_first_is_written =>
                                           
                        -- Writing "SECOND"
                       -- reg_wr_addr_i <= tmp_asi_in_data_2;
                        -- If is '0' - first time writing
                        if(ram_reset_flags(to_integer(unsigned(tmp_asi_in_data_2))) = '0') then
                            -- Write '1'
                            reg_wr_data_i <= std_logic_vector(to_unsigned(1,OUTPUT_BUS_WIDTH));
                            -- Set flag
                            ram_reset_flags(to_integer(unsigned(tmp_asi_in_data_2))) <= '1';     
                        else    
                                --  Inc read data for 1     
                                reg_wr_data_i <= std_logic_vector(unsigned(unsigned(tmp_reg_wr_data_i) + 1));                      
                        end if;                       
                        
                        if(asi_in_valid = '1' and last = '0') then
                            -- Next state
                            state_reg <= write_first_on_way_read_new_first_on_way;
                            -- Latch new data
                            reg_rd_addr_i <= asi_in_data;
                            -- Inc loaded data 
                            ram_data_counter <= ram_data_counter + 1;
                            -- Latch oaded data
                            tmp_asi_in_data_1 <= asi_in_data;
                            if(ram_data_counter = to_integer(unsigned(configuration_register)) - 1 and asi_in_eop = '1') then
                            
                                -- Reset flags
                                ram_data_counter <= (others => '0');
                                -- Next state
                                state_reg <= send;
                                -- Not ready
                                asi_in_ready <= '0';
                                -- Last data loaded
                                last <= '1';
                                -- End of calculation
                                status_register(END_CALC) <= '1';
                            
                            end if;
                            
                        else
                            -- If valid is not '1'
                            state_reg <= write_first_on_way;
                        end if;
                    
                    -- Data is written on 'FIRST' memory location
                    -- Data from 'SECOND' memory location was read
                    -- Data from new 'FIRST' memory location is read
                    when first_is_written_second_was_read_new_first_is_read => 
 
                        -- Writing "SECOND"
                        reg_wr_addr_i <= tmp_asi_in_data_2;  
                                         
                        if(ram_reset_flags(to_integer(unsigned(tmp_asi_in_data_2))) = '0') then
                            -- Write '1'
                            reg_wr_data_i <= std_logic_vector(to_unsigned(1,OUTPUT_BUS_WIDTH));
                            -- Set fleg
                            ram_reset_flags(to_integer(unsigned(tmp_asi_in_data_2))) <= '1';     
                        else           
                            -- Inc read data               
                            reg_wr_data_i <= std_logic_vector(unsigned(unsigned(tmp_reg_wr_data_i) + 1));                     
                        end if;
                        
                        -- If addresses are same  "FIRST" and  "SECOND"                                                      
                        if(tmp_asi_in_data_1 = tmp_asi_in_data_2) then
                        
                            -- Data which is written increment for 1
                            tmp_reg_wr_data_i <= std_logic_vector(unsigned(tmp_reg_wr_data_i) + 1);
                        
                        -- 'FIRST' and 'SECOND' are not same
                        else
                            
                            -- New temporary value
                            tmp_reg_wr_data_i <= std_logic_vector(unsigned(reg_rd_data_o) + 1);
                            -- Value for writing
                            reg_wr_data_i <= std_logic_vector(unsigned(reg_rd_data_o) + 1);
                        
                        end if;
                        
                        if (tmp_reg_wr_data_i_1_0_1(tmp_reg_wr_data_i_1_0_1'left) = '1' and tmp_reg_wr_data_i_1_0_1(tmp_reg_wr_data_i_1_0_1'left-1) = '0') then
                         
                            reg_wr_data_i <= std_logic_vector(unsigned(unsigned(tmp_reg_wr_data_i) + 1));
                            tmp_reg_wr_data_i_1_0_1 <= (others => '0');
                         
                        end if;
                    
                        if(asi_in_valid = '1' and last = '0') then
                            reg_rd_addr_i <= asi_in_data; 
                            ram_data_counter <= ram_data_counter + 1;
                            tmp_asi_in_data_1 <= tmp_asi_in_data_2;
                            tmp_asi_in_data_2 <= tmp_asi_in_data_3;
                            tmp_asi_in_data_3 <= asi_in_data;
                            
                            
                            if(ram_data_counter = to_integer(unsigned(configuration_register)) - 1 and asi_in_eop = '1') then
                            
                                -- Reset flags
                                ram_data_counter <= (others => '0');
                                -- Next state
                                state_reg <= send;
                                -- Not ready
                                asi_in_ready <= '0';
                                
                                last <= '1';
                                
                                status_register(END_CALC) <= '1';
                                
                                -- If addresses are same  "FIRST" and  "SECOND"                                                      
                                if(tmp_asi_in_data_2 = tmp_asi_in_data_3 and tmp_asi_in_data_2 = tmp_asi_in_data_1 and tmp_asi_in_data_3 /= asi_in_data) then
                                
                                    -- Data which is written increment for 1
                                    tmp_reg_wr_data_i <= std_logic_vector(unsigned(tmp_reg_wr_data_i) + 2);
                                
                                end if;
                                                            
                            end if;
                            
                        else
                            state_reg <= write_first_on_way_read_new_first_on_way;
                        end if;  
                        
                                                       
                        if(tmp_asi_in_data_2 = asi_in_data and tmp_asi_in_data_3 /= asi_in_data) then
                         
                             tmp_reg_wr_data_i_1_0_1 <= "11" & std_logic_vector(unsigned(reg_rd_data_o) + 1);
                             
                        end if; 
                         
                        if (tmp_reg_wr_data_i_1_0_1(tmp_reg_wr_data_i_1_0_1'left-1) = '1') then
                         
                             tmp_reg_wr_data_i <= std_logic_vector(unsigned(tmp_reg_wr_data_i_1_0_1(tmp_reg_wr_data_i_1_0_1'left-2 downto 0)));
                             tmp_reg_wr_data_i_1_0_1(tmp_reg_wr_data_i_1_0_1'left-1) <= '0';
                         
                        end if;   
                         
                               
                          
                when send => 
                
                    aso_out_sop <= '0';
                    aso_out_eop <= '0';
                
                    if(delay < 2) then
                
                        reg_wr_addr_i <= tmp_asi_in_data_2;  
                                 
                        if(ram_reset_flags(to_integer(unsigned(tmp_asi_in_data_2))) = '0') then
                            reg_wr_data_i <= std_logic_vector(to_unsigned(1,OUTPUT_BUS_WIDTH));
                            ram_reset_flags(to_integer(unsigned(tmp_asi_in_data_2))) <= '1';     
                        else                          
                            reg_wr_data_i <= std_logic_vector(unsigned(unsigned(tmp_reg_wr_data_i) + 1));                     
                        end if;
                    
                        reg_rd_en_i <= '0';
                    
                        -- If addresses are same  "FIRST" and  "SECOND"                                                      
                        if(tmp_asi_in_data_2 = tmp_asi_in_data_1) then
                    
                            -- Data which is written increment for 1
                            tmp_reg_wr_data_i <= std_logic_vector(unsigned(tmp_reg_wr_data_i) + 1);
                            
                        else
                        
                            tmp_reg_wr_data_i <= std_logic_vector(unsigned(reg_rd_data_o) + 1);
                            reg_wr_data_i <= std_logic_vector(unsigned(reg_rd_data_o) + 1);
                            reg_rd_en_i <= '1';
                    
                        end if;
                        
                        -- If addresses are same  "FIRST" and  "SECOND"                                                      
                        if(tmp_asi_in_data_3 = tmp_asi_in_data_2) then
                    
                            -- Data which is written increment for 1
                            tmp_reg_wr_data_i <= std_logic_vector(unsigned(reg_rd_data_o) + 1);
                    
                        end if; 
                    
                        tmp_asi_in_data_1 <= tmp_asi_in_data_2;
                        tmp_asi_in_data_2 <= tmp_asi_in_data_3; 
                        
                        delay <= delay + 1;                       
                        
                    else 
                    
                        reg_wr_en_i <= '0';
                        reg_rd_en_i <= '0';                     
               
                    end if;
                    
                    
                
                    aso_out_valid <= '0';
                    
                    if(aso_out_ready = '1') then
                    
                        if(delay < 4) then
                        
                            delay <= delay + 1;
                        
                        end if;
  
                        if(delay = 4) then
                        
                            aso_out_valid <= '1';
                            aso_out_sop <= '0';
                            if(ram_reset_flags(to_integer(counter - 2)) = '1')then
                                aso_out_data <= reg_rd_data_o;
                            else
                                aso_out_data <= (others => '0');
                            end if;
                            
                        end if;  
                              
                        reg_rd_en_i <= '1';
                        
                        if(counter < integer(NUMBER_OF_HISTOGRAM_ELEMENT)) then
                            reg_rd_addr_i <= std_logic_vector(counter(RAM_ADDRESS_WIDTH-1 downto 0));
                        end if;
                        
                        if(delay > 1) then
                            counter <= counter + 1;
                        end if;
                        
                        if(delay > 3) then
                            reg_wr_addr_i <= std_logic_vector(counter(RAM_ADDRESS_WIDTH-1 downto 0) - 2);
                            reg_wr_en_i <= '1';
                            reg_wr_data_i <= (others => '0');
                        end if;
                        
                        if(counter = integer(NUMBER_OF_HISTOGRAM_ELEMENT) + 1) then
                        
                            counter <= (others => '0');
                            state_reg <= idle;
                            ram_reset_flags <= (others => '0');
                            last <= '0';
                            aso_out_eop <= '1';
                            control_register <= (others => '0');
                            status_register <= (others => '0');
                            status_register(END_SEND) <= '1';
                            delay <= (others => '0');
                            reg_rd_en_i <= '0';
                            
                        end if;
                        
                    else
                    
                        delay <= (others => '0');  
                        
                        reg_rd_en_i <= '0';
                                            
                    end if;
                
                end case;                    
            
                if(control_register(START_CALC) = '1' and start_flag = '0') then
                
                    start_flag <= '1';
                    asi_in_ready <= '1';
                    config_reg <= configuration_register;
                    status_register(CALCULATING) <= '1';
                    status_register(END_SEND) <= '0'; 
                    status_register(END_CALC) <= '0';
                    cont_reg <= control_register;
                    
                    reg_wr_addr_i <= (others => '0');
                    reg_wr_data_i <= (others => '0');
                    reg_wr_en_i <= '0';
                    -- Read port
                    reg_rd_addr_i <= (others => '0');
                    reg_rd_en_i <= '0';
                     
                    tmp_asi_in_data_1 <= (others => '0');
                    tmp_asi_in_data_2 <= (others => '0');
                    tmp_asi_in_data_3 <= (others => '0');
                    tmp_reg_wr_data_i_1 <= (others => '0');
                    tmp_reg_wr_data_i_2 <= (others => '0');
                    tmp_reg_wr_data_i_3 <= (others => '0');
                    tmp_reg_wr_data_i <= (others => '0');
                    tmp_reg_wr_data_i_1_0_1 <= (others => '0'); 
                    
                end if;
                
                if(status_register(END_SEND) = '1' and start_flag = '1') then
                
                    start_flag <= '0';
                    config_flag <= '0';
               
                end if;
                
                if(control_register(START_SEND) = '1' and start_flag = '1') then
                
                    status_register(SENDING) <= '1';
                
                end if;
                
                if (control_register(STOP) = '1') then
                
                    start_flag <= '0';
                    status_register <= (others => '0');
                
                end if;
            
            end if;
    
        end if;
            
    end process sequential_process;

    avs_params_waitrequest <= '0';
    aso_out_empty <= '0';

end Behavioral;
