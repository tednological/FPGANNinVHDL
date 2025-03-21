library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Sig_ROM is
    generic (
        inWidth : integer := 10;
        dataWidth : integer :- 16;
    );
    port (
        clk : in std_logic;
        x : in std_logic_vector(inWidth-1 downto 0);
        Xout : out std_logic_vector(dataWidth-1 downto 0); 
    );
end entity;

architecture Behavioral of Sig_ROM is

    -- Create a memory array type
    type memory_array_t is array (0 to 2**inWidth) of std_logic_vector(dataWidth-1 downto 0);

    -- memory array
    signal mem : memory_array_t := (others => (others => '0')); -- This method allows us to initalize every spot in mem to 0

    -- This attribute tells Quartus to use "sigContent.mif" as the init file
    attribute ram_init_file : string;
    attribute ram_init_file of mem : signal is "sigContent";

    -- We'll store the computed address here
    signal y : unsigned(inWidth-1 downto 0);

begin
    -- Process: On rising edge of clk, compute the offset address.
    process(clk)
    begin
        if rising_edge(clk) then
            if signed(x) >= 0 then
                y <= unsigned(signed(x) + 2**(inWidth-1));
            else
                y <= unsigned(signed(x) - 2**(inWidth-1));
            end if;
        end if;
    end process;

    ------------------------------------------------------------------------
    -- Asynchronous read from the ROM using the computed address y
    ------------------------------------------------------------------------
    out <= mem(to_integer(y));

end architecture Behavioral;
