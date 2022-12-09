
module i_data_array  #(
    parameter i_s_offset = 5,
    parameter i_s_index = 3
)
(
    clk,
    rst,
    read,
    write_enable_internal,
    rindex,
    windex,
    datain,
    dataout
);

localparam i_s_mask   = 2**i_s_offset;
localparam i_s_line   = 8*i_s_mask;
localparam i_num_sets = 2**i_s_index;

input clk;
input rst;
input read;
input [i_s_mask-1:0] write_enable_internal;
input [i_s_index-1:0] rindex;
input [i_s_index-1:0] windex;
input [i_s_line-1:0] datain;
output logic [i_s_line-1:0] dataout;

logic [i_s_line-1:0] data [i_num_sets-1:0] /* synthesis ramstyle = "logic" */;
logic [i_s_line-1:0] _dataout;
assign dataout = _dataout;

always_ff @(posedge clk)
begin
    if (rst) begin
        for (int i = 0; i < i_num_sets; i++)
            data[i] <= '0;
    end
    else begin
        if (read)
            for (int i = 0; i < i_s_mask; i++)
                _dataout[8*i +: 8] <= (write_enable_internal[i] & (rindex == windex)) ?
                                      datain[8*i +: 8] : data[rindex][8*i +: 8];

        for (int i = 0; i < i_s_mask; i++)
        begin
            data[windex][8*i +: 8] <= write_enable_internal[i] ? datain[8*i +: 8] :
                                                    data[windex][8*i +: 8];
        end
    end
end

endmodule : i_data_array
