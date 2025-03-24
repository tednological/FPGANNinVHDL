library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;
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

    signal wen        : std_logic := '0';
    signal ren        : std_logic := '0';
    signal w_addr     : std_logic_vector(ADDRESS_WIDTH-1 downto 0) := (others => '0');
    signal r_addr     : std_logic_vector(ADDRESS_WIDTH downto 0)   := (others => '0');
    signal w_in       : std_logic_vector(dataWidth-1 downto 0)     := (others => '0');
    signal w_out      : std_logic_vector(dataWidth-1 downto 0);
    signal mul        : std_logic_vector((2*dataWidth)-1 downto 0) := (others => '0');
    signal sum        : std_logic_vector((2*dataWidth)-1 downto 0) := (others => '0');
    signal bias       : std_logic_vector((2*dataWidth)-1 downto 0) := (others => '0');
    signal weight_valid_reg : std_logic := '0';
    signal mult_valid      : std_logic := '0';
    signal mux_valid       : std_logic := '0';
    signal sigValid        : std_logic := '0';
    signal comboAdd        : std_logic_vector((2*dataWidth) downto 0) := (others => '0');
    signal biasAdd         : std_logic_vector((2*dataWidth) downto 0) := (others => '0');
    signal myInput_d       : std_logic_vector(dataWidth-1 downto 0)   := (others => '0');
    signal muxValid_d      : std_logic := '0';
    signal muxValid_f      : std_logic := '0';
    signal outValid_reg    : std_logic := '0';

    type bias_array_t is array (0 to 0) of std_logic_vector(31 downto 0);
    signal biasReg : bias_array_t := (others => (others => '0'));

    attribute ram_init_file : string;
    attribute ram_init_file of biasReg : signal is biasFile;

    begin
        -- Write all the weights from the .mif file
        process(clk)
        begin
            if rising_edge(clk) then
                if rst = '1' then
                    w_addr <= (others => '1');
                    wen    <= '0';
                elsif (weightValid = '1') and
                    (unsigned(config_layer_num) = layerNo) and
                    (unsigned(config_neuron_num) = neuronNo) then
                    -- Truncate 32 to dataWidth
                    w_in <= weightValue(dataWidth-1 downto 0);
                    w_addr <= std_logic_vector(unsigned(w_addr) + 1);
                    wen <= '1';
                else
                    wen <= '0';
                end if;
            end if;
        end process;

        -- All of the summation logic
        mux_valid <= mult_valid;
        comboAdd <= mul + sum;
        biasAdd <= bias + sum;
        ren <= myinputValid;

        -- Import the bias from the .mif
        process(clk)
        begin
            if rising_edge(clk) then
                -- Return dataWidth bits, then zero-extend
                bias <= biasReg(0)(dataWidth-1 downto 0) & (others => '0');
            end if;
        end process;

        -- Read by incrementing the address
        process(clk)
        begin
            if rising_edge(clk) then
                if rst = '1' or outvalid = '1' then
                    r_addr <= (others => '0');
                elsif myInputValid = '1' then
                    r_addr <= std_logic_vector(unsigned(r_addr) + 1);
                end if;
            end if;
        end process;

        --  multiplication
        process(clk)
        begin
            if rising_edge(clk) then
                mul <= std_logic_vector(signed(myInput_d) * signed(w_out));
            end if;
        end process;

        -- Finding the sum + saturation
        process(clk)
        begin
            if rising_edge(clk) then
                if (rst = '1') or (outValid_reg = '1') then
                    sum <= (others => '0');
                elsif (unsigned(r_addr) = numWeight) and (muxValid_f = '1') then
                    -- Add bias
                    -- checking 4 Signed overflow
                    -- Positive overflow
                    if (bias(2*dataWidth-1)='0' and sum(2*dataWidth-1)='0' and biasAdd(2*dataWidth)='1') then
                        sum(2*dataWidth-1) <= '0';
                        sum(2*dataWidth-2 downto 0) <= (others => '1');
                    -- Checking 4 negative overflow
                    elsif (bias(2*dataWidth-1)='1' and sum(2*dataWidth-1)='1' and biasAdd(2*dataWidth)='0') then
                        sum(2*dataWidth-1) <= '1';
                        sum(2*dataWidth-2 downto 0) <= (others => '0');
                    -- If there is no overflow, assign that baby
                    else
                        sum <= biasAdd((2*dataWidth)-1 downto 0);
                    end if;
                elsif (mux_valid = '1') then
                    -- mul + sum
                    if (mul(2*dataWidth-1)='0' and sum(2*dataWidth-1)='0' and comboAdd(2*dataWidth)='1') then
                        sum(2*dataWidth-1) <= '0';
                        sum(2*dataWidth-2 downto 0) <= (others => '1');
                    elsif (mul(2*dataWidth-1)='1' and sum(2*dataWidth-1)='1' and comboAdd(2*dataWidth)='0') then
                        sum(2*dataWidth-1) <= '1';
                        sum(2*dataWidth-2 downto 0) <= (others => '0');
                    else
                        sum <= comboAdd((2*dataWidth)-1 downto 0);
                    end if;
                end if;
            end if;
        end process;

        -- Control signals 
        process(clk)
        begin
            if rising_edge(clk) then
                myInput_d       <= myInput;
                weight_valid_reg <= myInputValid;
                mult_valid      <= weight_valid_reg;
                sigValid        <= ( (unsigned(r_addr)=numWeight) and (muxValid_f='1') ) ? '1' : '0';
                outValid_reg    <= sigValid;
                muxValid_d      <= mux_valid;
                muxValid_f      <= (not mux_valid) and muxValid_d;
            end if;
        end process;

        -- activation functions
        activate_sig: if (actType = "sigmoid") generate 
                signal sig_out : std_logic_vector(dataWidth-1 downto 0);
            begin 
                sig_unit entity work.sig_rom
                    generic map (
                        inWidth => sig
                    )
        -- Instantiate the weight memory
        weight_mem_inst: entity work.weight_memory
        generic map (
            numWeight     => numWeight,
            neuronNo      => neuronNo,
            layerNo       => layerNo,
            addressWidth  => ADDRESS_WIDTH,
            dataWidth     => dataWidth,
            weightFile    => weightFile
        )
        port map (
            clk  => clk,
            wen  => wen,
            ren  => ren,
            wadd => w_addr,
            radd => r_addr(ADDRESS_WIDTH-1 downto 0),
            win  => w_in,
            wout => w_out
        );

end architecture Behavioral;
