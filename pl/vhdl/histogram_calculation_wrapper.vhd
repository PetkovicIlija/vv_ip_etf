library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library work;
use work.math_real.all;

entity histogram_calculation_wrapper is

    Generic(
    
        INPUT_BUS_WIDTH : integer := 32;
        OUTPUT_BUS_WIDTH : integer := 32;
        PARAMETER_BUS_WIDTH : integer := 32;
        NUMBER_OF_HISTOGRAM_ELEMENT : integer := 256;
        MAX_NUMBER_OF_PROCESSING_DATA : integer := 100000;
        STATUS_REGISTER_WIDTH : integer := 8;
		NUMBER_OF_HISTOGRAM_COMPONENT : integer := 4; -- should be INPUT_BUS_WIDTH*NUMBER_OF_HISTOGRAM_COMPONENT = 32
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
	asi_in_empty          : in std_logic_vector(integer(ceil(log2(real(NUMBER_OF_HISTOGRAM_COMPONENT)))) - 1 downto 0);                                         --       .empty
    aso_out_data           : out std_logic_vector(OUTPUT_BUS_WIDTH - 1 downto 0);                    --    out.data
    aso_out_ready          : in  std_logic                     := '0';             --       .ready
    aso_out_valid          : out std_logic;                                        --       .valid
    aso_out_sop            : out std_logic;                                        --       .startofpacket
    aso_out_eop            : out std_logic;                                        --       .endofpacket
    aso_out_empty          : out std_logic_vector(integer(ceil(log2(real(NUMBER_OF_HISTOGRAM_COMPONENT)))) - 1 downto 0)                                         --       .empty
    );
    
end histogram_calculation_wrapper;



architecture Behavioral of histogram_calculation_wrapper is

	-- Components
	component histogram_calculation is

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
    
	end component;
	
	-- Types
	type PARAMS_WRITE_DATA is array (natural range <>) of std_logic_vector(PARAMETER_BUS_WIDTH - 1 downto 0);
	type OUT_DATA is array (natural range <>) of std_logic_vector(OUTPUT_BUS_WIDTH - 1 downto 0);
	type EMPTY is array (natural range <>) of std_logic_vector(integer(ceil(log2(real(NUMBER_OF_HISTOGRAM_COMPONENT)))) - 1 downto 0);
	
	-- Functions
	impure function config_reg_cal(conf : std_logic_vector) return PARAMS_WRITE_DATA is
		variable i : integer := 0;
		variable result : PARAMS_WRITE_DATA(NUMBER_OF_HISTOGRAM_COMPONENT - 1 downto 0);		
		variable tmp : std_logic_vector(integer(ceil(log2(real(NUMBER_OF_HISTOGRAM_COMPONENT)))) - 1 downto 0) := (others => '0');
		--variable mod_tmp : integer range 0 to 2**(NUMBER_OF_HISTOGRAM_ELEMENT) - 1;
		variable mod_tmp : unsigned(integer(ceil(log2(real(NUMBER_OF_HISTOGRAM_COMPONENT)))) - 1 downto 0) := (others => '0');
	begin
	
		--mod_tmp := to_integer(unsigned(conf)) mod NUMBER_OF_HISTOGRAM_COMPONENT;
		mod_tmp := unsigned(conf(integer(ceil(log2(real(NUMBER_OF_HISTOGRAM_COMPONENT)))) - 1 downto 0)); 
	
		for i in NUMBER_OF_HISTOGRAM_COMPONENT - 1 downto 0 loop
		
			result(i) :=  tmp & conf(conf'length - 1 downto tmp'length);
			if((i > NUMBER_OF_HISTOGRAM_COMPONENT - 1 - to_integer(mod_tmp)) and mod_tmp > 0) then
			
				result(i) := std_logic_vector(unsigned(result(i)) + 1);
				
			end if;
		
		end loop;
	
		return result;
	
	end function;
	
		-- Functions
	impure function eq(regs : PARAMS_WRITE_DATA;conf : std_logic_vector) return PARAMS_WRITE_DATA is
		variable i : integer := 0;
		variable result : PARAMS_WRITE_DATA(NUMBER_OF_HISTOGRAM_COMPONENT - 1 downto 0);		
	begin
	
		for i in NUMBER_OF_HISTOGRAM_COMPONENT - 1 downto 0 loop
		
			result(i) := conf;
		
		end loop;
	
		return result;
	
	end function;
	
	
	impure function valid_cal(valid : std_logic;empty : std_logic_vector) return std_logic_vector is
		variable result : std_logic_vector(NUMBER_OF_HISTOGRAM_COMPONENT - 1 downto 0) := (others => '0');
		variable i : integer := 0;
	begin
	
		for i in NUMBER_OF_HISTOGRAM_COMPONENT - 1 downto 0 loop
            if(valid = '1' and (i + 1 > unsigned(empty))) then
        
                result(i) := '1';
        
            else
            
                result(i) := '0';
            
            end if;
		end loop;
	
		return result;
	
	end function;
	
	impure function sum(data : OUT_DATA) return std_logic_vector is
		variable i : integer := 0;
		variable result : std_logic_vector(OUTPUT_BUS_WIDTH - 1 downto 0) := (others => '0');
	begin
	
		for i in NUMBER_OF_HISTOGRAM_COMPONENT - 1 downto 0 loop
	
			result := std_logic_vector(unsigned(result) + unsigned(data(i)));
	
		end loop;
		
		return result;
	
	end function;
	
	impure function valid_out(validd : std_logic_vector) return std_logic is
		variable i : integer := 0;
		variable result : std_logic := '0';
	begin
	
	    result := validd(validd'length - 1);
	    if(validd'length > 1) then
            for i in validd'length - 2 downto 0 loop
        
                result := result and validd(i);
        
            end loop;
		end if;
		
		return result;
	
	end function;
	
	
	
	 -- Constants
	 -- Status register values
    constant CONFIGURED : integer := 0;
    constant CALCULATING : integer := 1;
    constant END_CALC : integer := 2;
    constant SENDING : integer := 3;
    constant END_SEND : integer := 4;
    constant END_CLEAR : integer := 5;
    
    -- Control registers
    constant START_CALC : integer := 0;
    
    constant WIDTH_OF_CONFIGURATION_REGISTER : integer := integer(ceil(log2(real(MAX_NUMBER_OF_PROCESSING_DATA))));
    -- Constants
    -- Address of registers
    constant ADDRESS_OF_CONFIGURATION_REGISTER : std_logic_vector(1 downto 0) := "00";
    constant ADDRESS_OF_STATUS_REGISTER : std_logic_vector(1 downto 0) := "01";
    constant ADDRESS_OF_CONTROL_REGISTER : std_logic_vector(1 downto 0) := "10";


	-- Signals
	 signal avs_params_address_tmp     : std_logic_vector(1 downto 0)                     := "00";             -- params.address
	 signal avs_params_read_tmp        : std_logic                     := '0';             --       .read
	 signal avs_params_readdata_tmp    : std_logic_vector(PARAMETER_BUS_WIDTH - 1 downto 0);                     --       .readdata
	 signal avs_params_write_tmp       : std_logic                     := '0';             --       .write
	 --signal avs_params_writedata_tmp   : std_logic_vector(PARAMETER_BUS_WIDTH - 1 downto 0)  := (others => '0'); --       .writedata
	 signal avs_params_waitrequest_tmp : std_logic;
	 signal avs_params_writedata_tmp : PARAMS_WRITE_DATA(NUMBER_OF_HISTOGRAM_COMPONENT - 1 downto 0);
	 
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
	 
	 signal asi_in_data_tmp            : std_logic_vector(INPUT_BUS_WIDTH - 1 downto 0)  := (others => '0'); --     in.data
	 signal asi_in_ready_tmp           : std_logic_vector(NUMBER_OF_HISTOGRAM_COMPONENT - 1 downto 0);                                        --       .ready
	 signal asi_in_valid_tmp           : std_logic_vector(NUMBER_OF_HISTOGRAM_COMPONENT - 1 downto 0); 
	 signal asi_in_sop_tmp             : std_logic                     := '0';             --       .startofpacket
	 signal asi_in_eop_tmp             : std_logic_vector(NUMBER_OF_HISTOGRAM_COMPONENT - 1 downto 0);
	 signal aso_out_data_tmp           : OUT_DATA(NUMBER_OF_HISTOGRAM_COMPONENT - 1 downto 0);                    --    out.data
	 signal aso_out_ready_tmp          : std_logic                     := '0';             --       .ready
	 signal aso_out_valid_tmp          : std_logic_vector(NUMBER_OF_HISTOGRAM_COMPONENT - 1 downto 0);                                        --       .valid
	 signal aso_out_sop_tmp            : std_logic_vector(NUMBER_OF_HISTOGRAM_COMPONENT - 1 downto 0);                                        --       .startofpacket
	 signal aso_out_eop_tmp            : std_logic_vector(NUMBER_OF_HISTOGRAM_COMPONENT - 1 downto 0);                                        --       .endofpacket
	 signal aso_out_empty_tmp          : EMPTY(NUMBER_OF_HISTOGRAM_COMPONENT - 1 downto 0);
	 signal counter 						  : unsigned(integer(ceil(log2(real(MAX_NUMBER_OF_PROCESSING_DATA)))) - 1 downto 0);
	 signal tmp_ready : std_logic;
	 

begin

	-- Writing registers strobs
	configuration_register_strobe <= '1' when (avs_params_address = ADDRESS_OF_CONFIGURATION_REGISTER) and (avs_params_write = '1') else '0';
	status_register_strobe <= '1' when (avs_params_address = ADDRESS_OF_STATUS_REGISTER) and (avs_params_read = '1') else '0';
	control_register_strobe <= '1' when (avs_params_address = ADDRESS_OF_CONTROL_REGISTER) and (avs_params_write = '1') else '0';


	sequential_process : process(clk) is
	begin

		if(rising_edge(clk)) then
		
			if(reset = '1') then
			
				avs_params_address_tmp <= (others => '0');
				avs_params_read_tmp <= '0';
				avs_params_readdata_tmp <= (others => '0');
				avs_params_write_tmp <= '0';
				avs_params_writedata_tmp <= (others => (others => '0'));				
				configuration_register <= (others => '0');
				control_register <= (others => '0');
				status_register <= (others => '0');
				asi_in_eop_tmp <= (others => '0');
				counter <= (others => '0');
			
			else

				 avs_params_address_tmp <= (others => '0');
				 avs_params_write_tmp <= '0';
				 avs_params_writedata_tmp <= (others => (others => '0'));
				 asi_in_eop_tmp <= (others => '0');
			
				
				-- Loading configutration
				if(configuration_register_strobe =  '1') then
				  configuration_register <= avs_params_writedata(WIDTH_OF_CONFIGURATION_REGISTER - 1 downto 0);
				  -- Component is configured
					status_register(CONFIGURED) <= '1';				  
					avs_params_address_tmp <= avs_params_address;
					avs_params_write_tmp <= avs_params_write;
					avs_params_writedata_tmp <= config_reg_cal(avs_params_writedata);
				  
				end if;

				-- Loading control
				if(control_register_strobe =  '1') then
				   control_register <= avs_params_writedata(CONTROL_REGISTER_WIDTH - 1 downto 0); 
					avs_params_address_tmp <= avs_params_address;
					avs_params_write_tmp <= avs_params_write;
					avs_params_writedata_tmp <= eq(avs_params_writedata_tmp, avs_params_writedata);
				end if; 

				-- Reading status
				if(status_register_strobe =  '1') then
				  avs_params_readdata(STATUS_REGISTER_WIDTH - 1 downto 0) <= status_register;    
				end if;
				
				if(status_register(CONFIGURED) = '1' and asi_in_valid = '1' and tmp_ready = '1') then

					case(asi_in_empty) is
					
						when("00") =>
							if(counter + 4 >= unsigned(configuration_register) - 1) then
								asi_in_eop_tmp <= (others => '1');
								counter <= (others => '0');
							end if;
							counter <= counter + 4;
						when("01") =>							
							if(counter + 3 >= unsigned(configuration_register) - 1) then
								asi_in_eop_tmp <= (others => '1');
								counter <= (others => '0');
							end if;
							counter <= counter + 3;
						when("10") =>							
							if(counter + 2 >= unsigned(configuration_register) - 1) then
								asi_in_eop_tmp <= (others => '1');
								counter <= (others => '0');
							end if;
							counter <= counter + 2;
						when others =>
							if(counter + 1 >= unsigned(configuration_register) - 1) then
								asi_in_eop_tmp <= (others => '1');
								counter <= (others => '0');
							end if;
							counter <= counter + 1;					
					
					end case;
			
				end if;
			
			end if;
		
		end if;

	end process;
	
	
	label_Gen_histogram_calculation:
		for i in NUMBER_OF_HISTOGRAM_COMPONENT downto 1 generate
		
			histogram_calculation_i : histogram_calculation generic map (INPUT_BUS_WIDTH => INPUT_BUS_WIDTH/NUMBER_OF_HISTOGRAM_COMPONENT,
																						    OUTPUT_BUS_WIDTH => OUTPUT_BUS_WIDTH,
																						    PARAMETER_BUS_WIDTH => PARAMETER_BUS_WIDTH,
																							 NUMBER_OF_HISTOGRAM_ELEMENT => NUMBER_OF_HISTOGRAM_ELEMENT,
																							 MAX_NUMBER_OF_PROCESSING_DATA => MAX_NUMBER_OF_PROCESSING_DATA,
																							 STATUS_REGISTER_WIDTH => STATUS_REGISTER_WIDTH,
																							 CONTROL_REGISTER_WIDTH => CONTROL_REGISTER_WIDTH
																							 )
																				port map (reset => reset,
																							 avs_params_address => avs_params_address_tmp,
																							 avs_params_read => avs_params_read_tmp,
																							 avs_params_readdata => avs_params_readdata_tmp,
																							 avs_params_write => avs_params_write_tmp,
																							 avs_params_writedata => avs_params_writedata_tmp(i-1),
																							 avs_params_waitrequest => avs_params_waitrequest_tmp,
																							 clk => clk,
																							 asi_in_data => asi_in_data(i*(INPUT_BUS_WIDTH/NUMBER_OF_HISTOGRAM_COMPONENT) - 1 downto (i - 1)*(INPUT_BUS_WIDTH/NUMBER_OF_HISTOGRAM_COMPONENT)),
																							 asi_in_ready => asi_in_ready_tmp(i-1),
																							 asi_in_valid => asi_in_valid_tmp(i-1),
																							 asi_in_sop => asi_in_sop,
																							 asi_in_eop => asi_in_eop_tmp(i-1),
																						    aso_out_data => aso_out_data_tmp(i-1),
																							 aso_out_ready => aso_out_ready,
																							 aso_out_valid => aso_out_valid_tmp(i-1),
																							 aso_out_sop => aso_out_sop_tmp(i-1),         
																							 aso_out_eop => aso_out_sop_tmp(i-1),
																							 aso_out_empty => aso_out_empty_tmp(i-1)
																							 );
		
		
		end generate;
		
		  avs_params_waitrequest <= '0';
        aso_out_sop <= '0';
        aso_out_eop <= '0';
        aso_out_empty <= aso_out_empty_tmp(NUMBER_OF_HISTOGRAM_COMPONENT - 1);
        asi_in_valid_tmp <= valid_cal(asi_in_valid,asi_in_empty);				
        aso_out_data <= sum(aso_out_data_tmp);
        aso_out_valid <= valid_out(aso_out_valid_tmp);
        asi_in_ready <= valid_out(asi_in_ready_tmp);
		  tmp_ready <= valid_out(asi_in_ready_tmp);
        

	
	
	
end Behavioral;