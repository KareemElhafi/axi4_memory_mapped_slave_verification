`timescale 1ns/1ps

class axi4_sequencer;

    mailbox #(axi4_transaction) mbx_sequencer_to_driver;

    function new(mailbox #(axi4_transaction) mbx_sequencer_to_driver);
        this.mbx_sequencer_to_driver = mbx_sequencer_to_driver;
    endfunction

    task run();
        // This task will be called by the test to generate transactions
        // For now, it's a placeholder. Actual transaction generation logic
        // will be in the test module.
    endtask

endclass
