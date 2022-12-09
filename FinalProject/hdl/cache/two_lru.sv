

module two_lru #(
    parameter s_index = 3, 
    parameter num_ways = 2, 
    parameter width = $clog2(num_ways) 
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



localparam num_sets = 2**s_index;

int tem_width;

input clk;
input rst;
input read;
input load;
input [s_index-1:0] rindex;
input [s_index-1:0] windex;
input [width-1:0] recent_block_in;
output logic [width-1:0] evicted_way_out;

logic [num_ways-2:0] data [num_sets-1:0] /* synthesis ramstyle = "logic" */;

logic [num_ways-2:0] datain;
logic [num_ways-2:0] rdataout;
logic [num_ways-2:0] wdataout;
logic [width-1:0] evict;



always_comb begin
    wdataout = data[windex];
    rdataout = data[rindex];
    datain = wdataout;

    evict = '0;

    if (read) begin

	if (width==1) begin
		evict[0] = rdataout[0];
	end
         
	
    end
    if (load) begin
        for (int i = 0; i < width; i++) begin
                automatic int index = (2**i) - 1 + (recent_block_in>>(width-i));
                datain[index] =~recent_block_in[i];            
        end
    end
end

always_ff @(posedge clk)
begin
    if (rst) begin
        for (int i = 0; i < num_sets; ++i)
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

endmodule : two_lru
