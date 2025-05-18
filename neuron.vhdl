library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;
library work;
use work.config_pkg.all;
use work.math_helpers.all;
use work.mem_init_pkg.all;

entity neuron is 
    generic (
        layerNo : integer := 0; -- What layer this neuron belongs to
        neuronNo : integer := 0; -- its number on that layer
        numWeight : integer := 784; -- number of incoming weights
        dataWidth : integer := 16; -- width of data ports
        sigmoidSize : integer := 10; -- size of the sigmoid input
        weightIntWidth : integer := 4; -- size for the ReLU
        actType : string := "relu";
        biasFile : string := "C:/Users/tedno/OneDrive/Desktop/Projects/FPGA Neural Network/b_1_0.mif"; 
        weightFile: string := "C:/Users/tedno/OneDrive/Desktop/Projects/FPGA Neural Network/w_1_0.mif"
    );
    port (
        clk : in std_logic; 
        rst : in std_logic;
        myInputValid : in std_logic; -- says if the incoming signals is valid
        weightValid : in std_logic; -- controls write enable for the weight
        biasValid : in std_logic; -- makes sure that the bias is good before writing it
        neuronOutValid : out std_logic; -- says if the output is good to read
        myInput : in std_logic_vector(dataWidth-1 downto 0); -- The input to the neuron
        weightValue : in std_logic_vector(31 downto 0); -- goes into w_in which controls the weight memory
        biasValue : in std_logic_vector(31 downto 0); -- incoming bias value
        config_layer_num : in std_logic_vector(31 downto 0); -- Allows us to tell the neuron what layer it is and which weight to use
        config_neuron_num : in std_logic_vector(31 downto 0); -- same thing, but for the neuron number
        neuronOut : out std_logic_vector(dataWidth-1 downto 0) -- Output of the neuron. Heaviliy controlled by activation function
    );

end entity;

architecture Behavioral of neuron is

   -- bias type
   type bias_array_t is array (0 to 0) of std_logic_vector(31 downto 0); -- establishing the bias_array to be read from .mif

   
	-- impure funciton for initializing the bias from memory
    -- impure funciton allows us to reach outside the function to read a file
	impure function init_bias(fname : in string) return bias_array_t is
		-- pull one 16-bit word with init_mem 
		variable raw16 : mem_type(0 to 0) := init_mem(fname);
		variable res32 : bias_array_t;
	begin
        -- loop through the bias
		for i in res32'range loop
			-- use resize function to sign extend to 32 bits
			res32(i) := std_logic_vector(
								resize( signed(raw16(i)), 32 ) );
		end loop;
		return res32; 
	end function;
    -- Preload teh bias
   signal biasReg : bias_array_t := init_bias(biasFile);
   
	
    constant ADDRESS_WIDTH : integer := clog2(numWeight); -- Imported clog2 function from math_helpers.vhdl
    -- internal signals
    signal wen        : std_logic := '0'; -- write enable to get values from weight memory 
    signal ren        : std_logic := '0'; -- read enable for weight memory
    signal w_addr     : std_logic_vector(ADDRESS_WIDTH-1 downto 0) := (others => '0'); -- write pointer for the weight RAM, incremented once a valid weight is written
    signal r_addr     : std_logic_vector(ADDRESS_WIDTH downto 0)   := (others => '0'); -- read pointer for use during inference, each time a new "myInputValid" comes in, we increment
    signal w_in       : std_logic_vector(dataWidth-1 downto 0)     := (others => '0'); -- the weight we are about to store
    signal w_out      : std_logic_vector(dataWidth-1 downto 0); -- the weight value  fetched from RAM at addy r_addr
    signal mul        : std_logic_vector((2*dataWidth)-1 downto 0) := (others => '0'); -- stores multiplied value, product register
    signal sum        : std_logic_vector((2*dataWidth)-1 downto 0) := (others => '0'); -- running accumulator, sums each mul value, adds bias when r_addrt reaches numweight
    signal bias       : std_logic_vector((2*dataWidth)-1 downto 0) := (others => '0'); -- bias to be added at the end of the multiplication
    signal mult_valid      : std_logic := '0'; -- when input comes in, gives the green light to grab teh product of mul
    signal mux_valid       : std_logic := '0'; -- signals that comboAdd can be sent to sum
    signal sigValid        : std_logic := '0'; -- watches r_addr and signals when the neuronOut is valid
    signal comboAdd        : std_logic_vector((2*dataWidth) downto 0) := (others => '0'); -- contains the full running total, addign mul and sum
    signal biasAdd         : std_logic_vector((2*dataWidth) downto 0) := (others => '0'); -- contains the bias plus sum, taken at the end. full 32 bits instead of sum/bias 31, allows us to check for overflow in the MSB
    signal myInput_d       : std_logic_vector(dataWidth-1 downto 0)   := (others => '0'); -- used for aligning data by delaying clock cycles
    signal muxValid_d      : std_logic := '0'; -- copies mux_valid a cycle late
    signal muxValid_f      : std_logic := '0'; -- controls the logic to change sigValid, and thus have the neuron output
    signal neuronOutValid_reg    : std_logic := '0'; -- buffer for assigning the nOut as valid
    signal w_out_d 					: std_logic_vector(dataWidth-1 downto 0); -- holds the weight that is multiplied into mul, delayed
    signal DUMMY : std_logic; -- Used for delaying clock cycles
    signal weight_valid : std_logic := '0'; -- Used for delaying clock cycles
    -- signal r_addr_d1 : std_logic_vector(ADDRESS_WIDTH downto 0)   := (others => '0'); -- delayed r_addr for sync
    




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
        comboAdd <= std_logic_vector(resize(signed(mul), comboAdd'length) + resize(signed(sum), comboAdd'length));
        biasAdd <= std_logic_vector(resize(signed(bias), biasAdd'length) + resize(signed(sum), biasAdd'length));
        ren <= myinputValid; -- Once input is declared valid, start reading from weight memory

        -- Import the bias from the .mif
        process(clk)
        begin
            if rising_edge(clk) then
                -- Return dataWidth bits, then zero-extend
                if biasValid = '1'
                    and unsigned(config_layer_num)  = layerNo
                    and unsigned(config_neuron_num) = neuronNo
                then
                    bias <= std_logic_vector(resize( signed(biasValue(15 downto 0)), bias'length));
                end if; 
                
            end if;
        end process;

        -- Read by incrementing the address
        process(clk)
        begin
            if rising_edge(clk) then
                if rst = '1' then
                    r_addr <= (others => '0');
                elsif myInputValid = '1' then
                    
                    report "r_addr = "
                    & integer'image(to_integer(unsigned(r_addr)));    -- decimal
                    r_addr <= std_logic_vector(unsigned(r_addr) + 1);
                end if;
            end if;
        end process;

        --  multiplication
        process(clk)
        begin
            if rising_edge(clk) then
                if rst = '1' then
                    mul <= (others => '0');
                else    
                    mul <= std_logic_vector(signed(myInput_d) * signed(w_out));
                    if mult_valid = '1' then
                        report "MUL : " & integer'image(to_integer(signed((mul))))
                           severity note;
                    end if;
                    if (rst = '0' and biasValid = '1') then
                        report "Bias loaded = "
                           & integer'image(to_integer(signed(bias(31 downto 0))));
                     end if;
                end if;
            end if;
        end process;

        -- Finding the sum + saturation
        process(clk)
            variable sum_int : integer; -- Used for reporting Sum in simulation
        begin
            if rising_edge(clk) then
                if rst = '1' or neuronOutValid_reg = '1' then
                    sum <= (others => '0');
                elsif ((unsigned(r_addr) = numWeight) and mux_valid = '1') then
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
                        sum_int := to_integer(signed(sum));
                        report "SUM : " & integer'image(sum_int) severity note;
                    end if;
                end if;
                

            end if;

        end process;
        -- Control signals 
        process(clk)
        begin
            if rising_edge(clk) then
                if rst = '1' then
                    myInput_d            <= (others => '0');
                    mult_valid           <= '0';
                    mux_valid            <= '0';   
                    muxValid_d           <= '0';
                    --muxValid_f           <= '0';
                    sigValid             <= '0';
                    neuronOutValid_reg   <= '0';
                    DUMMY                <= '0';
                else

                    myInput_d <= myInput;
                    weight_valid <= myinputValid;
                    mult_valid <= weight_valid;
                    if ((unsigned(r_addr) = numWeight) and muxValid_f = '1') then
                        sigValid <= '1';
                    else
                        sigValid <= '0';
                    end if;
                    neuronOutValid_reg <= sigValid;
                    muxValid_d <= mux_valid;
                    muxValid_f <= (not mux_valid) and muxValid_d;
                end if;
            end if;
        end process;

		  neuronOutValid <= neuronOutValid_reg;
        -- activation functions
        activate_sig: if (actType = "sigmoid") generate
            signal sig_out : std_logic_vector(dataWidth-1 downto 0);
        begin
            sig_unit: entity work.sig_rom
                generic map (
						inWidth   => sigmoidSize,
                  dataWidth => dataWidth
                )
                port map (
                    clk => clk,
                    x   => sum((2*dataWidth-1) downto (2*dataWidth - sigmoidSize)),
                    Xout => sig_out
                );
            neuronOut <= sig_out;
        end generate activate_sig;
        
        activate_relu: if (actType = "relu") generate
            signal relu_out : std_logic_vector(dataWidth-1 downto 0);
				 -- slice of SUM that is (dataWidth + weightIntWidth) bits wide
			  constant RELU_IN_HI : integer := (2*dataWidth)-1;
			  constant RELU_IN_LO : integer := (2*dataWidth) - (dataWidth + weightIntWidth);
			  begin
            relu_unit: entity work.relu
                generic map (
                    dataWidth      => dataWidth,
                    weightIntWidth => weightIntWidth
                )
                port map (
                    clk  => clk,
						  x    => sum((2*dataWidth-1) downto (2*dataWidth - (dataWidth + weightIntWidth))),  
						  rout => relu_out
                );
            neuronOut <= relu_out;
        end generate activate_relu;
            
        -- Instantiate the weight memory
        weight_mem_inst: entity work.Weight_Memory
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
            wadd => w_addr(ADDRESS_WIDTH-1 downto 0),
            radd => r_addr(ADDRESS_WIDTH-1 downto 0),
            win  => w_in,
            wout => w_out
        );

end architecture Behavioral;
