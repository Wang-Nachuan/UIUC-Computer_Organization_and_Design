module i_array #(
	parameter i_s_index=3,
	parameter i_width=1
)
(
    clk,
    rst,
    read,
    load,
    rindex,
    windex,
    datain,
    dataout
);

localparam i_num_sets = 2**i_s_index;

input clk;
input rst;
input read;
input load;
input [i_s_index-1:0] rindex;
input [i_s_index-1:0] windex;
input [i_width-1:0] datain;
output logic [i_width-1:0] dataout;

logic [i_width-1:0] data [i_num_sets-1:0] /* synthesis ramstyle = "logic" */;
logic [i_width-1:0] _dataout;
assign dataout = _dataout;

always_ff @(posedge clk)
begin
    if (rst) begin
        for (int i = 0; i < i_num_sets; ++i)
            data[i] <= '0;
    end
    else begin
        if (read)
            _dataout <= (load  & (rindex == windex)) ? datain : data[rindex];

        if(load)
            data[windex] <= datain;
    end
end

endmodule : i_array
