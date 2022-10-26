module cdb 
import rv32i_types::*;
(
    input cdb_data cdb_data_in,
    input cdb_flush cdb_flush_in,
    output cdb_data cdb_data_out,
    output cdb_flush cdb_flush_out
);

assign cdb_data_out = cdb_data_in;
assign cdb_flush_out = cdb_flush_in;

endmodule : cdb