package i_cache_types;

//constant
//adjust number of sets by i_s_index
//adjust number of ways by i_num_ways
//adjust pipelined/non-pipelined by i_input_size

parameter i_s_index  = 3; //adjust number of sets from s_index
parameter i_num_ways = 2; //adjust number of ways

parameter i_s_offset = 5;
parameter i_input_size = 64; //32 for non-pipelined L1 cache, 64 for pipelined L1 instruction cache
parameter i_size = 8*(2**i_s_offset); //cacheline size of instruction cache
parameter i_s_tag    = 32 - i_s_offset - i_s_index; 
parameter i_s_mask   = 2**i_s_offset; //32
parameter i_s_line   = 8*i_s_mask; //256
parameter i_num_sets = 2**i_s_index; //8
parameter i_width = $clog2(i_num_ways);


// select address from cpu or lower memory
typedef enum logic {
    CPU_ADDRESS = 1'b0,
    LOWER_MEM_ADDRESS = 1'b1
} i_address_selection;

// write enable signal selction; 
typedef enum logic [1:0] {
    ALL_NOT_ENABLE = 2'b00, //all bits disabled
    ALL_ENABLE  = 2'b01, //all bits enabled
    CPU_ENABLE  = 2'b10  //determined by cpu
} i_write_enable_selection;

// select data to come from CPU or lower memory
typedef enum logic {
    CPU_DATA = 1'b0,
    LOWER_MEM_DATA = 1'b1
} i_write_data_selection;


endpackage
