library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.config_pkg.all;

entity Weight_Memory is
    generic (
        numWeight     : integer := 3;
        neuronNo      : integer := 5;
        layerNo       : integer := 1;
        addressWidth  : integer := 10;
        dataWidth     : integer := 16
    );
    port (
        clk  : in  std_logic;
        wen  : in  std_logic;
        ren  : in  std_logic;
        wadd : in  std_logic_vector(addressWidth-1 downto 0);
        radd : in  std_logic_vector(addressWidth-1 downto 0);
        win  : in  std_logic_vector(dataWidth-1 downto 0);
        wout : out std_logic_vector(dataWidth-1 downto 0);
    );
end entity;

architecture Behavioral of Weight_Memory is

    type memory_array_t is array (0 to numWeight-1) of std_logic_vector(dataWidth-1 downto 0);
    signal mem : memory_array_t := (others => (others => '0'));
    signal rdata : std_logic_vector(dataWidth-1 downto 0);

    -- Quartus-specific attributes for block RAM and initialization
    attribute ramstyle : string;
    attribute ramstyle of mem : signal is "M9K";

    attribute ram_init_file : string;
    attribute ram_init_file of mem : signal is "w_1_15";

begin

    -- Write process
    process(clk)
    begin
        if rising_edge(clk) then
            if wen = '1' then
                mem(to_integer(unsigned(wadd))) <= win;
            end if;
        end if;
    end process;

    -- Read process
    process(clk)
    begin
        if rising_edge(clk) then
            if ren = '1' then
                rdata <= mem(to_integer(unsigned(radd)));
            end if;
        end if;
    end process;

    wout <= rdata;

end architecture;
