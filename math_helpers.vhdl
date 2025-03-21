package math_helpers is
    function clog2(n : integer) return integer;
end package;

package body math_helpers is
    function clog2(n : integer) return integer is
        variable res : integer := 0;
        variable val : integer := n - 1;
    begin
        while val > 0 loop
            res := res + 1;
            val := val / 2;
        end loop;
        return res;
    end function;
end package body;
