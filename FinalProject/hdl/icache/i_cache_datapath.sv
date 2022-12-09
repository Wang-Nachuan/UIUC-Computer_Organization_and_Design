
module i_cache_datapath 
import i_cache_types::*;
(
    input clk,
    input rst,
    
    // Inputs
    // CPU
    // input mem_write,
    input mem_read,
    input logic [31:0] mem_address,

    // Controller
    input i_write_data_selection write_data_selection_t,
    input load,
    input i_write_enable_selection write_en_selection_t,
    input valid_in,
    // input dirty_in,
    input load_lru,
    input i_address_selection address_selection_t,
    // lower memory
    input logic [i_s_line-1:0] pmem_data_in,

    // Outputs
    // CPU
    output logic [i_s_line-1:0] mem_rdata256,
    // Controller
    output logic hit_output,

    output logic [i_width-1:0] evicting_way,
    // lower memory

    output logic [31:0] pmem_address_t,
    output logic [31:0] mem_address_loaded
);

    // Internal Signals
    logic [i_num_ways-1:0] valid;
    logic [i_num_ways-1:0][i_s_tag-1:0] tag;
    logic [i_num_ways-1:0][i_s_line-1:0] block;
    logic [i_num_ways-1:0] hit;

    logic [i_s_mask-1:0] write_enable_internal;

    logic [i_width-1:0] block_selection;

    // logic dirty_value;
    logic valid_value;
    logic [i_num_ways-1:0][i_s_mask-1:0] write_value;
    logic [i_num_ways-1:0] load_value;

    logic [i_s_line-1:0] write_data;
    logic [i_s_line-1:0] mem_rdata256_in;
    logic [i_s_line-1:0] mem_wdata256_out;
    logic [i_s_mask-1:0] mem_byte_enable256_out;


    logic read;

    logic [i_s_index-1:0] index;
    logic [i_s_index-1:0] windex;
    logic [i_s_tag-1:0] tag_in;

    logic [i_width-1:0] recent_block;
    logic [i_width-1:0] way_counter;
    logic [i_width-1:0] way_counter2;



    genvar j;
    
    generate

        for (j = 0; j < i_num_ways; j++) begin : MODULES
            i_array #(.i_s_index(i_s_index)) VALID (
                .clk(clk),
                .rst(rst),
                .read(read),
                .load(load_value[j]),
                .rindex(index),
                .windex(windex),
                .datain(valid_value),
                .dataout(valid[j])
            );

            i_array #(.i_width(i_s_tag), .i_s_index(i_s_index)) TAG (
                .clk(clk),
                .rst(rst),
                .read(read),
                .load(load_value[j]),
                .rindex(index),
                .windex(windex),
                .datain(tag_in),
                .dataout(tag[j])
            );
            i_data_array #(.i_s_offset(i_s_offset), .i_s_index(i_s_index)) DATA (
                .clk(clk),
                .rst(rst),
                .read(read),
                .write_enable_internal(write_value[j]),
                .rindex(index),
                .windex(windex),
                .datain(write_data),
                .dataout(block[j])
            );
        end
        
    endgenerate

generate 
    if (i_width==1) begin
    i_two_lru #(.i_s_index(i_s_index), .i_num_ways(i_num_ways)) i_evicting_way (
        .clk(clk),
        .rst(rst),
        .read(read),
        .load(load_lru),
        .rindex(index),
        .windex(windex),
        .recent_block_in(recent_block),
        .evicted_way_out(evicting_way)
    );
    end

    else begin
    i_lru #(.i_s_index(i_s_index), .i_num_ways(i_num_ways)) i_evicting_way (
        .clk(clk),
        .rst(rst),
        .read(read),
        .load(load_lru),
        .rindex(index),
        .windex(windex),
        .recent_block_in(recent_block),
        .evicted_way_out(evicting_way)
    );
    end

endgenerate

    i_input_buffer input_buffer (
        .*,

        .load_input_buffer(mem_read),
        .mem_address_in(mem_address)
    );
    


    assign index = mem_address[i_s_offset +: i_s_index];
    assign windex = mem_address_loaded[i_s_offset +: i_s_index];
    assign tag_in = mem_address_loaded[i_s_offset+i_s_index +: i_s_tag];
    // assign windex = mem_address[i_s_offset +: i_s_index];
    // assign tag_in = mem_address[i_s_offset+i_s_index +: i_s_tag];


    assign read = mem_read;


    assign hit_output = ~(hit == '0);

    always_comb begin : HIT_SELECT
        recent_block = '0;
	    way_counter='0;
        for (int i = 0; i < i_num_ways; i++) begin
            hit[i] = valid[i] & (tag_in == tag[i]);
            if (hit[i]) begin
                
		recent_block=way_counter;
		way_counter='0;
	    end
	    way_counter=way_counter+'1;
        end
    end

    

    
    always_comb begin : WRITE_ENABLE_SELECT
        case (write_en_selection_t)
            ALL_NOT_ENABLE: write_enable_internal = '0;
            ALL_ENABLE:  write_enable_internal = '1;

            CPU_ENABLE:  write_enable_internal = '0;

        endcase
    end

    always_comb begin : DEMUXES

        valid_value = valid_in;
        unique case (load)
            1'b1: begin
		way_counter2='0;
                for (int i = 0; i < i_num_ways; i++) begin
                    
			if (way_counter2 == block_selection) begin
                        write_value[i] = write_enable_internal;
                        load_value[i] = load;
			way_counter2='0;
                    end
                    else begin
                        write_value[i] = '0;
                        load_value[i] = '0;
                    end
		    way_counter2=way_counter2+'1;
                end
            end
            1'b0: begin
                write_value = '0;
                load_value = '0;
            end
            default: begin
                write_value = '0;
                load_value = '0;
            end
        endcase
    end

    always_comb begin : WRITE_DATA_SELECT
        case (write_data_selection_t)

            CPU_DATA: write_data = '0;
            LOWER_MEM_DATA: write_data = pmem_data_in;
        endcase
    end

    logic [i_s_offset-1:0] zeros = '0;

    always_comb begin : PHYSICAL_ADDRESS_SELECT
        case (address_selection_t)
            CPU_ADDRESS:    pmem_address_t = {mem_address[31:i_s_offset], zeros};
            LOWER_MEM_ADDRESS: begin
                pmem_address_t = {tag[evicting_way], index, zeros};
            end
        endcase
    end

    always_comb begin : ASSIGN_READ_DATA
        mem_rdata256_in = block[recent_block];
    end


    always_comb begin : SELECT_BLOCK
        if (hit_output) block_selection = recent_block;
        else     block_selection = evicting_way;
    end

endmodule : i_cache_datapath
