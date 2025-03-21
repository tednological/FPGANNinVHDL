library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.config_pkg.all;
use work.math_helpers.all;

entity neuron is 
    generic (
        layerNo : integer := 0;
        neuronNo : integer := 0;
        numWeight : integer := 784;
        dataWidth : integer := 16;
        sigmoidSize : integer := 5;
        weightIntWidth : integer := 1;
        actType : string := "relu";
        biasFile : string := "";
        weightFile: string := ""; 
    );
    port (
        clk : in std_logic;
        rst : in std_logic;
        myInputValid : in std_logic;
        weightValid : in std_logic;
        biasValid : in std_logic;
        neuronOutvalid : in std_logic;
        myInput : in std_logic_vector(dataWidth-1 downto 0);
        weightValue : in std_logic_vector(31 downto 0);
        biasValue : in std_logic_vector(31 downto 0);
        config_layer_num : in std_logic_vector(31 downto 0);
        config_neuron_num : in std_logic_vector(31 downto 0);
        neuronOut : out std_logic_vector(dataWidth-1 downto 0);
    )

end entity;

architecture Behavioral of neuron is
    constant ADDRESS_WIDTH : integer := clog2(NUM_WEIGHT); -- Imported clog2 function from math_helpers.vhdl

    signal wen : std_logic;
    signal ren : std_logic;
    signal w_addr : std_logic_vector(addressWidth-1 downto 0);
    signal r_addr : std_logic_vector(addressWidth downto 0);
    signal w_in : std_logic_vector(dataWidth-1 downto 0);
    signal w_out : std_logic_vector(dataWidth-1 downto 0);
    signal mul : std_logic_vector(2*dataWidth-1 downto 0);
    signal sum : std_logic_vector(2*dataWidth-1 downto 0);
    signal bias : std_logic_vector(2*dataWidth-1 downto 0);
    type bias_array_t is array (0 to 0) of std_logic_vector(31 downto 0);
    signal biasReg : bias_array_t := (others => (others => '0'));
    signal weight_valid : std_logic;
    signal mult_valid : std_logic;
    signal mux_valid : std_logic;
    signal sigValid : std_logic;
    signal comboAdd : std_logic_vector(2*dataWidth downto 0);
    signal biasAdd : std_logic_vector(2*dataWidth downto 0);
    signal myinputd : std_logic_vector(dataWidth-1 downto 0);
    signal muxValid_d : std_logic;
    signal muxValid_f : std_logic;
    signal addr : std_logic_vector(ADDRESS_WIDTH-1 downto 0);

    begin
        process(clk)
        begin
                if(rst) then --Reset cases for writing
                    w_addr <= (others => '1');
                    wen <= 0;
                elsif(weightValid and (config_layer_num==layerNo) and (config_layer_num==neuronNo)) then
                    w_in <= weightValue;
                    w_addr <= w_addr +1;
                    wen <= 1;
                else 
                    wen <= 0;
                end if;
        end process;

        mux_valid <= mult_valid;
        comboAdd <= mul + sum;
        biasAdd <= bias + sum;
        ren <= myinputValid;


    type bias_array_t is array (0 to 0) of std_logic_vector(31 downto 0);
    signal biasReg : bias_array_t := (others => (others => '0'));

    attribute ram_init_file : string;
    attribute ram_init_file of biasReg : signal is "biasFile";

    signal addr  : integer range 0 to 0;
    signal bias  : std_logic_vector(31 downto 0);
    constant DATA_WIDTH : integer := 16;

    process(clk)
    begin
        if rising_edge(clk) then
            bias <= biasReg(addr)(DATA_WIDTH - 1 downto 0) & (others => '0');
        end if;
    end process;


end architecture;
