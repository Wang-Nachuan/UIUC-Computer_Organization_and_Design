

module i_two_lru #(
    parameter i_s_index = 3, 
    parameter i_num_ways = 2, 
    parameter i_width = $clog2(i_num_ways) 
)
(
    clk,
    rst,
    read,
    load,
    rindex,
    windex,
    recent_block_in,
    evicted_way_out
);



localparam i_num_sets = 2**i_s_index;
int tem_width;

input clk;
input rst;
input read;
input load;
input [i_s_index-1:0] rindex;
input [i_s_index-1:0] windex;
input [i_width-1:0] recent_block_in;
output logic [i_width-1:0] evicted_way_out;

logic [i_num_ways-2:0] data [i_num_sets-1:0] /* synthesis ramstyle = "logic" */;

logic [i_num_ways-2:0] datain;
logic [i_num_ways-2:0] rdataout;
logic [i_num_ways-2:0] wdataout;
logic [i_width-1:0] evict;



always_comb begin
    wdataout = data[windex];
    rdataout = data[rindex];
    datain = wdataout;
    evict = '0;

    if (read) begin


	if (i_width==1) begin
		evict[0] = rdataout[0];
	end



	          
	
    end
    if (load) begin
        for (int i = 0; i < i_width; i++) begin
                automatic int index = (2**i) - 1 + (recent_block_in>>(i_width-i));
                datain[index] =~recent_block_in[i];            
        end
    end
end

always_ff @(posedge clk)
begin
    if (rst) begin
        for (int i = 0; i < i_num_sets; ++i)
            data[i] <= '0;
        evicted_way_out <= '0;
    end
    else begin
        if (read)
            evicted_way_out <= evict;

        if(load)
            data[windex] <= datain;
    end
end

endmodule : i_two_lru
