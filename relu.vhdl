library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity relu is
    generic (
        dataWidth : integer := 16;
        weightIntWidth : integer := 4;
    );
    port (
        clk : in std_logic;
        x : in std_logic_vector(2*dataWidth downto 0);
        rout : out std_logic_vector(dataWidth downto 0);
    );
end entity relu;

architecture Behavioral of relu is
    process(clk)
        -- "overflow_bits" grabs the top (weightIntWidth+1) bits
        variable overflow_bits_len : integer := weightIntWidth + 1;  -- how many bits to check
        variable overflow_bits     : std_logic_vector(weightIntWidth downto 0);

        --  slicing out the final dataWidth bits
        variable hi : integer := (2*dataWidth - 1) - weightIntWidth;
        variable lo : integer := hi - (dataWidth - 1);
    begin
        if rising_edge(clk) then

            -- check sign bit => x >= 0 if sign is '0'
            if x((2*dataWidth)-1) = '0' then
                -- grab the top (weightIntWidth+1) bits
                overflow_bits := x((2*dataWidth - 1) downto ((2*dataWidth - 1) - (overflow_bits_len - 1)));

                -- If any of those bits are 1 we saturate
                if overflow_bits /= (others => '0') then
                    -- if we have positive overflow, saturate that baby
                    out <= '0' & (others => '1');
                else
                    -- if it doesn't overflow, slice em
                    out <= x(hi downto lo);
                end if;

            else
                -- x is negative means that the ReLU output = 0
                out <= (others => '0');
            end if;

        end if;
    end process;

end architecture Behavioral;
