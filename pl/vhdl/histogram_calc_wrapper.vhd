
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity histogram_calc_wrapper is

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


end histogram_calc_wrapper;

architecture Behavioral of histogram_calc_wrapper is

    -- Components
    component histogram_calc is
    
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
    
    end component;

begin

    histogram_calc_inst : histogram_calc generic map(INPUT_BUS_WIDTH => INPUT_BUS_WIDTH,
                                                     OUTPUT_BUS_WIDTH => OUTPUT_BUS_WIDTH,
                                                     PARAMETER_BUS_WIDTH => PARAMETER_BUS_WIDTH,
                                                     NUMBER_OF_HISTOGRAM_ELEMENT => NUMBER_OF_HISTOGRAM_ELEMENT,
                                                     MAX_NUMBER_OF_PROCESSING_DATA => MAX_NUMBER_OF_PROCESSING_DATA,
                                                     STATUS_REGISTER_WIDTH => STATUS_REGISTER_WIDTH,
                                                     CONTROL_REGISTER_WIDTH => CONTROL_REGISTER_WIDTH
                                                     )
                                            port map(reset => reset,
                                                     avs_params_address => avs_params_address,
                                                     avs_params_read => avs_params_read,
                                                     avs_params_readdata => avs_params_readdata,
                                                     avs_params_write => avs_params_write,
                                                     avs_params_writedata => avs_params_writedata,
                                                     avs_params_waitrequest => avs_params_waitrequest,                               
                                                     clk => clk,
                                                     asi_in_data => asi_in_data,
                                                     asi_in_ready => asi_in_ready,
                                                     asi_in_valid => asi_in_valid,
                                                     asi_in_sop => asi_in_sop,
                                                     asi_in_eop => asi_in_eop,
                                                     aso_out_data => aso_out_data,
                                                     aso_out_ready => aso_out_ready,
                                                     aso_out_valid => aso_out_valid,
                                                     aso_out_sop => aso_out_sop,
                                                     aso_out_eop => aso_out_eop,
                                                     aso_out_empty => aso_out_empty
                                                     );



end Behavioral;
