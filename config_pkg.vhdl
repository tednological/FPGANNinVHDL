library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package config_pkg is
    constant PRETRAINED       : boolean := true;
    constant NUM_LAYERS       : integer := 5;
    constant DATA_WIDTH       : integer := 31;
    constant NUM_NEURON_LAYER1: integer := 30;
    constant NUM_WEIGHT_LAYER1: integer := 784;
    constant LAYER1_ACT_TYPE  : string  := "sigmoid";
    constant NUM_NEURON_LAYER2: integer := 30;
    constant NUM_WEIGHT_LAYER2: integer := 30;
    constant LAYER2_ACT_TYPE  : string  := "sigmoid";
    constant NUM_NEURON_LAYER3: integer := 10;
    constant NUM_WEIGHT_LAYER3: integer := 30;
    constant LAYER3_ACT_TYPE  : string  := "sigmoid";
    constant NUM_NEURON_LAYER4: integer := 10;
    constant NUM_WEIGHT_LAYER4: integer := 10;
    constant LAYER4_ACT_TYPE  : string  := "sigmoid";
    constant NUM_NEURON_LAYER5: integer := 10;
    constant NUM_WEIGHT_LAYER5: integer := 10;
    constant LAYER5_ACT_TYPE  : string  := "hardmax";
    constant SIGMOID_SIZE     : integer := 5;
    constant WEIGHT_INT_WIDTH : integer := 1;
end package config_pkg;

package body config_pkg is
end package body config_pkg;
