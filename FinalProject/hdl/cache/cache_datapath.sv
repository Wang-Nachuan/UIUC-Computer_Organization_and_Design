module cache_datapath 
import d_cache_types::*;
(
    input clk,
    input rst,
    // Input signal
    // CPU
    input mem_write,
    input mem_read,
    input logic [31:0] mem_address,
    input logic [s_line-1:0] mem_wdata256,
    input logic [s_mask-1:0] mem_byte_enable256,
    // Cache Control
    input load,
    input valid_in,
    input dirty_in,
    input load_lru,
    input logic load_buffer,
    input logic write_back_busy,
    input d_write_data_selection write_data_selection_t,
    input d_write_enable_selection write_en_selection_t,
    input d_address_selection d_address_selection_t,
    // Physical memory
    input logic [s_line-1:0] pmem_data_in,
    // Output signal
    // CPU
    output logic [s_line-1:0] mem_rdata256,
    // Cache Control
    output logic hit_output,
    output logic [num_ways-1:0] dirty_out,
    output logic [width-1:0] evicting_way,
    // Physical memory
    output logic [s_line-1:0] pmem_data_t,
    output logic [31:0] pmem_address_t,
    output logic [31:0] mem_address_loaded
);

    logic [num_ways-1:0] valid;
    logic [num_ways-1:0][s_tag-1:0] tag;
    logic [num_ways-1:0][s_line-1:0] block;
    logic [num_ways-1:0] hit;
    logic [num_ways-1:0][s_mask-1:0] write_value;
    logic [num_ways-1:0] load_value;    
    logic [s_mask-1:0] write_enable_internal;
    logic [s_mask-1:0] mem_byte_enable256_out;
    logic [width-1:0] block_selection;
    logic [width-1:0] recent_block;
    logic [width-1:0] way_counter;
    logic [width-1:0] way_counter2;
    logic [s_line-1:0] write_data;
    logic [s_line-1:0] mem_rdata256_in;
    logic [s_line-1:0] mem_wdata256_out;
    logic [s_index-1:0] index;
    logic [s_index-1:0] windex;
    logic [s_tag-1:0] tag_in;
    logic [s_offset-1:0] zeros = '0;
    logic [31:0] write_back_addr_in;
    logic [31:0] write_back_addr_out;
    logic read;
    logic dirty_value;
    logic valid_value;




    genvar j;
    generate

        for (j = 0; j < num_ways; j++) begin : ARRAY_BLOCK
            array #(.s_index(s_index)) VALID_ARRAY (
                .clk(clk),
                .rst(rst),
                .read(read),
                .load(load_value[j]),
                .rindex(index),
                .windex(windex),
                .datain(valid_value),
                .dataout(valid[j])
            );
            array #(.s_index(s_index)) DIRTY_ARRAY (
                .clk(clk),
                .rst(rst),
                .read(read),
                .load(load_value[j]),
                .rindex(index),
                .windex(windex),
                .datain(dirty_value),
                .dataout(dirty_out[j])
            );
            array #(.width(s_tag), .s_index(s_index)) TAG_ARRAY (
                .clk(clk),
                .rst(rst),
                .read(read),
                .load(load_value[j]),
                .rindex(index),
                .windex(windex),
                .datain(tag_in),
                .dataout(tag[j])
            );
            data_array #(.s_offset(s_offset), .s_index(s_index)) DATA_ARRAY (
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
        if (width==1) begin
            two_lru #(.s_index(s_index), .num_ways(num_ways)) LRU_ARRAY (
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
            lru_array #(.s_index(s_index), .num_ways(num_ways)) LRU_ARRAY (
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

    input_buffer #(.s_offset(s_offset), .s_index(s_index)) input_buffer (
        .*,
        .load_input_buffer(mem_read | mem_write),
        .mem_address_in(mem_address)
    );

    //write back buffer for dirty evict
    write_back_buffer #(.s_offset(s_offset), .s_index(s_index)) wb_buffer(
        .clk(clk),
        .rst(rst),
        .load_buffer(load_buffer),
        .evict_data_in(block[evicting_way]),
        .evict_data_out(pmem_data_t),
        .write_back_addr_in(write_back_addr_in),
        .write_back_addr_out(write_back_addr_out)
    );
    

    assign index = mem_address[s_offset +: s_index];
    assign windex = mem_address_loaded[s_offset +: s_index];
    assign tag_in = mem_address_loaded[s_offset+s_index +: s_tag];
    assign read = mem_read | mem_write;
    assign hit_output = ~(hit == '0);

    always_comb begin : FIND_HIT_WAY
        recent_block = '0;
	    way_counter='0;
        for (int i = 0; i < num_ways; i++) begin
            hit[i] = valid[i] & (tag_in == tag[i]);
            if (hit[i]) begin
                recent_block=way_counter;
                way_counter='0;
	    end
	            way_counter=way_counter+'1;
        end
    end
    
    always_comb begin : SELECT_WRITE_ENABLE
        case (write_en_selection_t)
            ALL_NOT_ENABLE: write_enable_internal = '0;
            ALL_ENABLE:  write_enable_internal = '1;
            CPU_ENABLE:  write_enable_internal = mem_byte_enable256_out;
        endcase
    end

    always_comb begin : FIND_DIRTY_AND_VALID_WAY
        valid_value = valid_in;
        dirty_value = dirty_in;
        unique case (load)
            1'b1: begin
		        way_counter2='0;
                for (int i = 0; i < num_ways; i++) begin
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


    assign write_back_addr_in = {tag[evicting_way], index, zeros};
    always_comb begin : PHYSICAL_ADDRESS_SELECT
        case (d_address_selection_t)
            CPU_ADDRESS:    pmem_address_t = {mem_address[31:s_offset], zeros};
            LOWER_MEM_ADDRESS: begin
                if (write_back_busy) begin
                    pmem_address_t = write_back_addr_out;
                end
                else begin
                    pmem_address_t = {tag[evicting_way], index, zeros};
                end
            end
        endcase
    end

    always_comb begin : SLECT_WRITE_DATA
        case (write_data_selection_t)
            CPU_DATA: write_data = mem_wdata256_out;
            LOWER_MEM_DATA: write_data = pmem_data_in;
        endcase
    end

    always_comb begin : SELECT_BLOCK
        if (hit_output) 
            block_selection = recent_block;
        else     
            block_selection = evicting_way;
    end

    assign    mem_rdata256_in = block[recent_block];
    

endmodule : cache_datapath

