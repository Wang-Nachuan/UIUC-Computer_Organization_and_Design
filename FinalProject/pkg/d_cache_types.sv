package d_cache_types;

//constant
//adjust number of sets by s_index
//adjust number of ways by num_ways
//input_size is 32 for L1 cache, input size is 256 for L2 cache

parameter s_index  = 3;    // Number of set
parameter num_ways = 2;

parameter s_offset = 5; 
parameter input_size = 32;
parameter size = (2**s_offset)*8; //cacheline size
parameter s_tag    = 32 - s_offset - s_index; //24
parameter s_mask   = 2**s_offset; //32
parameter s_line   = 8*s_mask; //256
parameter num_sets = 2**s_index; //8
parameter width = $clog2(num_ways); 

// select address from cpu or lower memory
typedef enum logic {
    CPU_ADDRESS = 1'b0,
    LOWER_MEM_ADDRESS = 1'b1
} d_address_selection;

// write enable signal selction; 
typedef enum logic [1:0] {
    ALL_NOT_ENABLE = 2'b00,
    ALL_ENABLE  = 2'b01,
    CPU_ENABLE  = 2'b10
} d_write_enable_selection;

// select data to come from CPU or lower memory
typedef enum logic {
    CPU_DATA = 1'b0,
    LOWER_MEM_DATA = 1'b1
} d_write_data_selection;



endpackage
