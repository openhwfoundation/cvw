onerror {resume}
quietly virtual signal -install /testbench/dut/core/ifu/bpred/bpred { /testbench/dut/core/ifu/bpred/bpred/PostSpillInstrRawF[11:7]} rd
quietly WaveActivateNextPane {} 0
add wave -noupdate /testbench/clk
add wave -noupdate /testbench/reset
add wave -noupdate /testbench/memfilename
add wave -noupdate /testbench/debugger_filename
add wave -noupdate /testbench/dut/core/SATP_REGW
add wave -noupdate /testbench/dut/core/InstrValidM
add wave -noupdate -group HDU -expand -group hazards /testbench/dut/core/hzu/RetM
add wave -noupdate -group HDU -expand -group hazards -color Pink /testbench/dut/core/hzu/TrapM
add wave -noupdate -group HDU -expand -group hazards /testbench/dut/core/ieu/c/LoadStallD
add wave -noupdate -group HDU -expand -group hazards /testbench/dut/core/ifu/IFUStallF
add wave -noupdate -group HDU -expand -group hazards /testbench/dut/core/hzu/BPWrongE
add wave -noupdate -group HDU -expand -group hazards /testbench/dut/core/hzu/LSUStallM
add wave -noupdate -group HDU -expand -group hazards /testbench/dut/core/ieu/c/MDUStallD
add wave -noupdate -group HDU -expand -group hazards /testbench/dut/core/hzu/DivBusyE
add wave -noupdate -group HDU -expand -group hazards /testbench/dut/core/hzu/FDivBusyE
add wave -noupdate -group HDU -group traps /testbench/dut/core/priv/priv/trap/InstrMisalignedFaultM
add wave -noupdate -group HDU -group traps /testbench/dut/core/priv/priv/trap/InstrAccessFaultM
add wave -noupdate -group HDU -group traps /testbench/dut/core/priv/priv/trap/IllegalInstrFaultM
add wave -noupdate -group HDU -group traps /testbench/dut/core/priv/priv/trap/BreakpointFaultM
add wave -noupdate -group HDU -group traps /testbench/dut/core/priv/priv/trap/LoadMisalignedFaultM
add wave -noupdate -group HDU -group traps /testbench/dut/core/priv/priv/trap/StoreAmoMisalignedFaultM
add wave -noupdate -group HDU -group traps /testbench/dut/core/priv/priv/trap/LoadAccessFaultM
add wave -noupdate -group HDU -group traps /testbench/dut/core/priv/priv/trap/StoreAmoAccessFaultM
add wave -noupdate -group HDU -group traps /testbench/dut/core/priv/priv/trap/EcallFaultM
add wave -noupdate -group HDU -group traps /testbench/dut/core/priv/priv/trap/InstrPageFaultM
add wave -noupdate -group HDU -group traps /testbench/dut/core/priv/priv/trap/LoadPageFaultM
add wave -noupdate -group HDU -group traps /testbench/dut/core/priv/priv/trap/StoreAmoPageFaultM
add wave -noupdate -group HDU -group traps /testbench/dut/core/priv/priv/trap/InterruptM
add wave -noupdate -group HDU -group traps /testbench/dut/core/priv/priv/trap/HPTWInstrAccessFaultM
add wave -noupdate -group HDU -group traps /testbench/dut/core/priv/priv/pmd/WFITimeoutM
add wave -noupdate -group HDU -group Flush -color Yellow /testbench/dut/core/FlushD
add wave -noupdate -group HDU -group Flush -color Yellow /testbench/dut/core/FlushE
add wave -noupdate -group HDU -group Flush -color Yellow /testbench/dut/core/FlushM
add wave -noupdate -group HDU -group Flush -color Yellow /testbench/dut/core/FlushW
add wave -noupdate -group HDU -group Stall -color Orange /testbench/dut/core/StallF
add wave -noupdate -group HDU -group Stall -color Orange /testbench/dut/core/StallD
add wave -noupdate -group HDU -group Stall -color Orange /testbench/dut/core/StallE
add wave -noupdate -group HDU -group Stall -color Orange /testbench/dut/core/StallM
add wave -noupdate -group HDU -group Stall -color Orange /testbench/dut/core/StallW
add wave -noupdate -group HDU -group interrupts /testbench/dut/core/priv/priv/trap/PendingIntsM
add wave -noupdate -group HDU -group interrupts /testbench/dut/core/priv/priv/trap/InstrValidM
add wave -noupdate -group HDU -group interrupts /testbench/dut/core/priv/priv/trap/ValidIntsM
add wave -noupdate -group HDU -group interrupts /testbench/dut/core/hzu/WFIInterruptedM
add wave -noupdate -group {instruction pipeline} /testbench/InstrFName
add wave -noupdate -group {instruction pipeline} /testbench/dut/core/ifu/PostSpillInstrRawF
add wave -noupdate -group {instruction pipeline} /testbench/dut/core/ifu/InstrD
add wave -noupdate -group {instruction pipeline} /testbench/dut/core/ifu/InstrE
add wave -noupdate -group {instruction pipeline} /testbench/dut/core/ifu/InstrM
add wave -noupdate -group PCS /testbench/dut/core/ifu/PCNextF
add wave -noupdate -group PCS /testbench/dut/core/ifu/PCF
add wave -noupdate -group PCS /testbench/dut/core/ifu/PCD
add wave -noupdate -group PCS /testbench/dut/core/PCE
add wave -noupdate -group PCS /testbench/dut/core/PCM
add wave -noupdate -group {PCNext Generation} /testbench/dut/core/ifu/PCPlus2or4F
add wave -noupdate -group {PCNext Generation} /testbench/dut/core/ifu/IEUAdrE
add wave -noupdate -group {PCNext Generation} /testbench/dut/core/ifu/PCSrcE
add wave -noupdate -group {PCNext Generation} /testbench/dut/core/ifu/PC1NextF
add wave -noupdate -group {PCNext Generation} -label {NextValidPCE (from bpred)} /testbench/dut/core/ifu/NextValidPCE
add wave -noupdate -group {PCNext Generation} /testbench/dut/core/ifu/CSRWriteFenceM
add wave -noupdate -group {PCNext Generation} -expand -group pcmux3 -group xepc /testbench/dut/core/priv/priv/csr/MEPC_REGW
add wave -noupdate -group {PCNext Generation} -expand -group pcmux3 -group xepc /testbench/dut/core/priv/priv/csr/SEPC_REGW
add wave -noupdate -group {PCNext Generation} -expand -group pcmux3 -group xepc /testbench/dut/core/priv/priv/csr/mretM
add wave -noupdate -group {PCNext Generation} -expand -group pcmux3 -group xepc /testbench/dut/core/priv/priv/EPCM
add wave -noupdate -group {PCNext Generation} -expand -group pcmux3 /testbench/dut/core/priv/priv/csr/TrapVectorM
add wave -noupdate -group {PCNext Generation} -expand -group pcmux3 /testbench/dut/core/priv/priv/csr/TrapM
add wave -noupdate -group {PCNext Generation} -expand -group pcmux3 /testbench/dut/core/priv/priv/RetM
add wave -noupdate -group {PCNext Generation} -expand -group pcmux3 /testbench/dut/core/ifu/UnalignedPCNextF
add wave -noupdate -group {PCNext Generation} /testbench/dut/core/ifu/PCNextF
add wave -noupdate -group {PCNext Generation} /testbench/dut/core/ifu/PCF
add wave -noupdate -group {PCNext Generation} /testbench/dut/core/ifu/bpred/bpred/NextValidPCE
add wave -noupdate -group {PCNext Generation} /testbench/dut/core/ifu/PCSpillNextF
add wave -noupdate -group {PCNext Generation} /testbench/dut/core/ifu/PCSpillF
add wave -noupdate -group ifu -group Bpred -group {branch update selection inputs} /testbench/dut/core/ifu/bpred/bpred/Predictor/DirPredictor/GHRM
add wave -noupdate -group ifu -group Bpred -group {branch update selection inputs} {/testbench/dut/core/ifu/bpred/bpred/RASPredictor/memory[5]}
add wave -noupdate -group ifu -group Bpred -group {branch update selection inputs} {/testbench/dut/core/ifu/bpred/bpred/RASPredictor/memory[4]}
add wave -noupdate -group ifu -group Bpred -group {branch update selection inputs} {/testbench/dut/core/ifu/bpred/bpred/RASPredictor/memory[3]}
add wave -noupdate -group ifu -group Bpred -group {branch update selection inputs} {/testbench/dut/core/ifu/bpred/bpred/RASPredictor/memory[2]}
add wave -noupdate -group ifu -group Bpred -group {branch update selection inputs} {/testbench/dut/core/ifu/bpred/bpred/RASPredictor/memory[1]}
add wave -noupdate -group ifu -group Bpred -group {branch update selection inputs} {/testbench/dut/core/ifu/bpred/bpred/RASPredictor/memory[0]}
add wave -noupdate -group ifu -group Bpred -group RAS -expand /testbench/dut/core/ifu/bpred/bpred/RASPredictor/memory
add wave -noupdate -group ifu -group Bpred -group RAS /testbench/dut/core/ifu/bpred/bpred/RASPredictor/Ptr
add wave -noupdate -group ifu -group Bpred -divider {class check}
add wave -noupdate -group ifu -group Bpred -group prediction /testbench/dut/core/ifu/bpred/bpred/RASPCF
add wave -noupdate -group ifu -group Bpred -group prediction -expand -group ex /testbench/dut/core/ifu/bpred/bpred/PCSrcE
add wave -noupdate -group ifu /testbench/dut/core/ifu/InstrRawF
add wave -noupdate -group ifu /testbench/dut/core/ifu/PostSpillInstrRawF
add wave -noupdate -group ifu /testbench/dut/core/ifu/IFUStallF
add wave -noupdate -group ifu -group Spill /testbench/dut/core/ifu/Spill/spill/CurrState
add wave -noupdate -group ifu -group Spill -expand -group takespill /testbench/dut/core/ifu/Spill/spill/SpillF
add wave -noupdate -group ifu -group Spill -expand -group takespill /testbench/dut/core/ifu/Spill/spill/IFUCacheBusStallF
add wave -noupdate -group ifu -group Spill -expand -group takespill /testbench/dut/core/ifu/Spill/spill/ITLBMissOrUpdateAF
add wave -noupdate -group ifu -group Spill -expand -group takespill /testbench/dut/core/ifu/Spill/spill/TakeSpillF
add wave -noupdate -group ifu -group bus /testbench/dut/core/ifu/bus/icache/ahbcacheinterface/HSIZE
add wave -noupdate -group ifu -group bus /testbench/dut/core/ifu/bus/icache/ahbcacheinterface/HBURST
add wave -noupdate -group ifu -group bus /testbench/dut/core/ifu/bus/icache/ahbcacheinterface/HTRANS
add wave -noupdate -group ifu -group bus /testbench/dut/core/ifu/bus/icache/ahbcacheinterface/HWRITE
add wave -noupdate -group ifu -group bus /testbench/dut/core/ifu/bus/icache/ahbcacheinterface/HADDR
add wave -noupdate -group ifu -group bus /testbench/dut/core/ifu/bus/icache/ahbcacheinterface/AHBBuscachefsm/Flush
add wave -noupdate -group ifu -group bus -color Gold /testbench/dut/core/ifu/bus/icache/ahbcacheinterface/AHBBuscachefsm/CurrState
add wave -noupdate -group ifu -group bus /testbench/dut/core/ifu/bus/icache/ahbcacheinterface/HRDATA
add wave -noupdate -group ifu -expand -group icache /testbench/dut/core/ifu/bus/icache/icache/Stall
add wave -noupdate -group ifu -expand -group icache /testbench/dut/core/ifu/bus/icache/icache/FlushStage
add wave -noupdate -group ifu -expand -group icache -color Gold /testbench/dut/core/ifu/bus/icache/icache/cachefsm/CurrState
add wave -noupdate -group ifu -expand -group icache /testbench/dut/core/ifu/ITLBMissF
add wave -noupdate -group ifu -expand -group icache /testbench/dut/core/ifu/PCNextF
add wave -noupdate -group ifu -expand -group icache /testbench/dut/core/ifu/PCPF
add wave -noupdate -group ifu -expand -group icache /testbench/dut/core/ifu/bus/icache/icache/cachefsm/AnyMiss
add wave -noupdate -group ifu -expand -group icache /testbench/dut/core/ifu/bus/icache/icache/CacheRW
add wave -noupdate -group ifu -expand -group icache /testbench/dut/core/ifu/bus/icache/icache/Stall
add wave -noupdate -group ifu -expand -group icache /testbench/dut/core/ifu/bus/icache/icache/CacheAccess
add wave -noupdate -group ifu -expand -group icache -expand -group {fsm out and control} /testbench/dut/core/ifu/bus/icache/icache/HitWay
add wave -noupdate -group ifu -expand -group icache -expand -group {fsm out and control} /testbench/dut/core/ifu/ICacheStallF
add wave -noupdate -group ifu -expand -group icache -expand -group memory /testbench/dut/core/ifu/bus/icache/icache/CacheBusAdr
add wave -noupdate -group ifu -expand -group icache -expand -group memory /testbench/dut/core/ifu/bus/icache/icache/cachefsm/CacheBusAck
add wave -noupdate -group ifu -expand -group icache /testbench/dut/core/ifu/bus/icache/icache/VictimWay
add wave -noupdate -group ifu -expand -group icache -expand -group lru /testbench/dut/core/ifu/bus/icache/icache/vict/cacheLRU/FlushStage
add wave -noupdate -group ifu -expand -group icache -expand -group lru /testbench/dut/core/ifu/bus/icache/icache/vict/cacheLRU/LRUWriteEn
add wave -noupdate -group ifu -expand -group icache -expand -group lru /testbench/dut/core/ifu/bus/icache/icache/vict/cacheLRU/LRUUpdate
add wave -noupdate -group ifu -expand -group icache -expand -group lru {/testbench/dut/core/ifu/bus/icache/icache/vict/cacheLRU/LRUMemory[50]}
add wave -noupdate -group ifu -expand -group icache -expand -group lru /testbench/dut/core/ifu/bus/icache/icache/vict/cacheLRU/ReadLRU
add wave -noupdate -group ifu -expand -group icache -expand -group lru /testbench/dut/core/ifu/bus/icache/icache/vict/cacheLRU/NextLRU
add wave -noupdate -group ifu -expand -group icache -expand -group lru /testbench/dut/core/ifu/bus/icache/icache/vict/cacheLRU/ForwardLRU
add wave -noupdate -group ifu -expand -group icache -expand -group lru /testbench/dut/core/ifu/bus/icache/icache/vict/cacheLRU/BypassedLRU
add wave -noupdate -group ifu -expand -group icache -expand -group lru /testbench/dut/core/ifu/bus/icache/icache/vict/cacheLRU/CurrLRU
add wave -noupdate -group ifu -expand -group icache -expand -group lru /testbench/dut/core/ifu/bus/icache/icache/vict/cacheLRU/LRUMemory
add wave -noupdate -group ifu -expand -group icache /testbench/dut/core/ifu/bus/icache/icache/SelAdrTag
add wave -noupdate -group ifu -expand -group icache /testbench/dut/core/ifu/bus/icache/icache/AdrSelMuxSelTag
add wave -noupdate -group ifu -expand -group icache /testbench/dut/core/ifu/bus/icache/icache/vict/cacheLRU/PAdr
add wave -noupdate -group ifu -expand -group icache -group way3 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[3]/SelectedWriteWordEn}
add wave -noupdate -group ifu -expand -group icache -group way3 -label tag {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[3]/CacheTagMem/ram/RAM}
add wave -noupdate -group ifu -expand -group icache -group way3 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[3]/ValidBits}
add wave -noupdate -group ifu -expand -group icache -group way3 -group way3word0 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[3]/word[0]/wordram/CacheDataMem/dout}
add wave -noupdate -group ifu -expand -group icache -group way3 -group way3word0 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[3]/word[0]/wordram/CacheDataMem/ram/RAM}
add wave -noupdate -group ifu -expand -group icache -group way3 -group way3word1 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[3]/word[1]/wordram/CacheDataMem/dout}
add wave -noupdate -group ifu -expand -group icache -group way3 -group way3word1 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[3]/word[1]/wordram/CacheDataMem/ram/RAM}
add wave -noupdate -group ifu -expand -group icache -group way3 -group way3word2 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[3]/word[2]/wordram/CacheDataMem/dout}
add wave -noupdate -group ifu -expand -group icache -group way3 -group way3word2 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[3]/word[2]/wordram/CacheDataMem/ram/RAM}
add wave -noupdate -group ifu -expand -group icache -group way3 -group way3word3 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[3]/word[3]/wordram/CacheDataMem/dout}
add wave -noupdate -group ifu -expand -group icache -group way3 -group way3word3 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[3]/word[3]/wordram/CacheDataMem/ram/RAM}
add wave -noupdate -group ifu -expand -group icache -group way2 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[2]/SelectedWriteWordEn}
add wave -noupdate -group ifu -expand -group icache -group way2 -label tag {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[2]/CacheTagMem/ram/RAM}
add wave -noupdate -group ifu -expand -group icache -group way2 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[2]/ValidBits}
add wave -noupdate -group ifu -expand -group icache -group way2 -expand -group way2word0 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[2]/word[0]/wordram/CacheDataMem/dout}
add wave -noupdate -group ifu -expand -group icache -group way2 -expand -group way2word0 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[2]/word[0]/wordram/CacheDataMem/ram/RAM}
add wave -noupdate -group ifu -expand -group icache -group way2 -group way2word1 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[2]/word[1]/wordram/CacheDataMem/dout}
add wave -noupdate -group ifu -expand -group icache -group way2 -group way2word1 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[2]/word[1]/wordram/CacheDataMem/ram/RAM}
add wave -noupdate -group ifu -expand -group icache -group way2 -group way2word2 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[2]/word[2]/wordram/CacheDataMem/dout}
add wave -noupdate -group ifu -expand -group icache -group way2 -group way2word2 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[2]/word[2]/wordram/CacheDataMem/ram/RAM}
add wave -noupdate -group ifu -expand -group icache -group way2 -group way2word3 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[2]/word[3]/wordram/CacheDataMem/dout}
add wave -noupdate -group ifu -expand -group icache -group way2 -group way2word3 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[2]/word[3]/wordram/CacheDataMem/ram/RAM}
add wave -noupdate -group ifu -expand -group icache -group way1 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[1]/HitWay}
add wave -noupdate -group ifu -expand -group icache -group way1 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[1]/SelectedWriteWordEn}
add wave -noupdate -group ifu -expand -group icache -group way1 -label tag {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[1]/CacheTagMem/ram/RAM}
add wave -noupdate -group ifu -expand -group icache -group way1 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[1]/ValidBits}
add wave -noupdate -group ifu -expand -group icache -group way1 -group way1word0 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[1]/word[0]/wordram/CacheDataMem/dout}
add wave -noupdate -group ifu -expand -group icache -group way1 -group way1word0 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[1]/word[0]/wordram/CacheDataMem/ram/RAM}
add wave -noupdate -group ifu -expand -group icache -group way1 -group way1word1 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[1]/word[1]/wordram/CacheDataMem/dout}
add wave -noupdate -group ifu -expand -group icache -group way1 -group way1word1 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[1]/word[1]/wordram/CacheDataMem/ram/RAM}
add wave -noupdate -group ifu -expand -group icache -group way1 -group way1word2 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[1]/word[2]/wordram/CacheDataMem/dout}
add wave -noupdate -group ifu -expand -group icache -group way1 -group way1word2 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[1]/word[2]/wordram/CacheDataMem/ram/RAM}
add wave -noupdate -group ifu -expand -group icache -group way1 -group way1word3 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[1]/word[3]/wordram/CacheDataMem/dout}
add wave -noupdate -group ifu -expand -group icache -group way1 -group way1word3 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[1]/word[3]/wordram/CacheDataMem/ram/RAM}
add wave -noupdate -group ifu -expand -group icache -group way0 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[0]/SelectedWriteWordEn}
add wave -noupdate -group ifu -expand -group icache -group way0 -label tag -expand {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[0]/CacheTagMem/ram/RAM}
add wave -noupdate -group ifu -expand -group icache -group way0 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[0]/ValidBits}
add wave -noupdate -group ifu -expand -group icache -group way0 -group way0word0 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[0]/word[0]/wordram/CacheDataMem/dout}
add wave -noupdate -group ifu -expand -group icache -group way0 -group way0word0 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[0]/word[0]/wordram/CacheDataMem/ram/RAM}
add wave -noupdate -group ifu -expand -group icache -group way0 -group way0word1 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[0]/word[1]/wordram/CacheDataMem/dout}
add wave -noupdate -group ifu -expand -group icache -group way0 -group way0word1 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[0]/word[1]/wordram/CacheDataMem/ram/RAM}
add wave -noupdate -group ifu -expand -group icache -group way0 -group way0word2 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[0]/word[2]/wordram/CacheDataMem/dout}
add wave -noupdate -group ifu -expand -group icache -group way0 -group way0word2 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[0]/word[2]/wordram/CacheDataMem/ram/RAM}
add wave -noupdate -group ifu -expand -group icache -group way0 -group way0word3 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[0]/word[3]/wordram/CacheDataMem/dout}
add wave -noupdate -group ifu -expand -group icache -group way0 -group way0word3 {/testbench/dut/core/ifu/bus/icache/icache/CacheWays[0]/word[3]/wordram/CacheDataMem/ram/RAM}
add wave -noupdate -group ifu -group itlb /testbench/dut/core/ifu/immu/immu/TLBWrite
add wave -noupdate -group ifu -group itlb /testbench/dut/core/ifu/ITLBMissF
add wave -noupdate -group ifu -group itlb /testbench/dut/core/ifu/immu/immu/VAdr
add wave -noupdate -group ifu -group itlb /testbench/dut/core/ifu/immu/immu/PhysicalAddress
add wave -noupdate -group ifu -group itlb /testbench/dut/core/ifu/immu/immu/tlb/tlb/tlbcam/Matches
add wave -noupdate -group ifu -group itlb /testbench/dut/core/ifu/immu/immu/InstrPageFaultF
add wave -noupdate -group ifu -group itlb /testbench/dut/core/ifu/immu/immu/tlb/tlb/tlbcam/TLBFlush
add wave -noupdate -group ifu -group itlb -group key21 {/testbench/dut/core/ifu/immu/immu/tlb/tlb/tlbcam/camlines[21]/Valid}
add wave -noupdate -group ifu -group itlb -group key21 {/testbench/dut/core/ifu/immu/immu/tlb/tlb/tlbcam/camlines[21]/PageType}
add wave -noupdate -group ifu -group itlb -group key21 {/testbench/dut/core/ifu/immu/immu/tlb/tlb/tlbcam/camlines[21]/Key}
add wave -noupdate -group ifu -group itlb -group key21 {/testbench/dut/core/ifu/immu/immu/tlb/tlb/tlbcam/camlines[21]/Key0}
add wave -noupdate -group ifu -group itlb -group key21 {/testbench/dut/core/ifu/immu/immu/tlb/tlb/tlbcam/camlines[21]/Key1}
add wave -noupdate -group ifu -group itlb -group key21 {/testbench/dut/core/ifu/immu/immu/tlb/tlb/tlbcam/camlines[21]/Query0}
add wave -noupdate -group ifu -group itlb -group key21 {/testbench/dut/core/ifu/immu/immu/tlb/tlb/tlbcam/camlines[21]/Query1}
add wave -noupdate -group ifu -group itlb -group key19 {/testbench/dut/core/ifu/immu/immu/tlb/tlb/tlbcam/camlines[19]/Valid}
add wave -noupdate -group ifu -group itlb -group key19 {/testbench/dut/core/ifu/immu/immu/tlb/tlb/tlbcam/camlines[19]/PageTypeWriteVal}
add wave -noupdate -group ifu -group itlb -group key19 {/testbench/dut/core/ifu/immu/immu/tlb/tlb/tlbcam/camlines[19]/PageType}
add wave -noupdate -group ifu -group itlb -group key19 {/testbench/dut/core/ifu/immu/immu/tlb/tlb/tlbcam/camlines[19]/Key}
add wave -noupdate -group ifu -group itlb -group key19 {/testbench/dut/core/ifu/immu/immu/tlb/tlb/tlbcam/camlines[19]/Key0}
add wave -noupdate -group ifu -group itlb -group key19 {/testbench/dut/core/ifu/immu/immu/tlb/tlb/tlbcam/camlines[19]/Key1}
add wave -noupdate -group ifu -group itlb -group key19 {/testbench/dut/core/ifu/immu/immu/tlb/tlb/tlbcam/camlines[19]/Query0}
add wave -noupdate -group ifu -group itlb -group key19 {/testbench/dut/core/ifu/immu/immu/tlb/tlb/tlbcam/camlines[19]/Query1}
add wave -noupdate -group {Decode Stage} /testbench/dut/core/ifu/PCD
add wave -noupdate -group {Decode Stage} /testbench/dut/core/ifu/InstrD
add wave -noupdate -group {Decode Stage} /testbench/InstrDName
add wave -noupdate -group {Decode Stage} /testbench/dut/core/ieu/c/InstrValidD
add wave -noupdate -group {Decode Stage} /testbench/dut/core/ieu/c/RegWriteD
add wave -noupdate -group {Decode Stage} /testbench/dut/core/ieu/c/RdD
add wave -noupdate -group {Decode Stage} /testbench/dut/core/ieu/c/Rs1D
add wave -noupdate -group {Decode Stage} /testbench/dut/core/ieu/c/Rs2D
add wave -noupdate -group {Execution Stage} /testbench/dut/core/ifu/PCE
add wave -noupdate -group {Execution Stage} /testbench/dut/core/ifu/InstrE
add wave -noupdate -group {Execution Stage} /testbench/InstrEName
add wave -noupdate -group {Execution Stage} /testbench/dut/core/ieu/c/InstrValidE
add wave -noupdate -group {Execution Stage} /testbench/dut/core/ieu/dp/SrcAE
add wave -noupdate -group {Execution Stage} /testbench/dut/core/ieu/dp/SrcBE
add wave -noupdate -group {Execution Stage} /testbench/dut/core/ieu/dp/ALUResultE
add wave -noupdate -group {Execution Stage} /testbench/dut/core/ieu/dp/ResultW
add wave -noupdate -expand -group {Memory Stage} /testbench/dut/core/InstrValidM
add wave -noupdate -expand -group {Memory Stage} /testbench/dut/core/PCM
add wave -noupdate -expand -group {Memory Stage} /testbench/dut/core/InstrM
add wave -noupdate -expand -group {Memory Stage} /testbench/InstrMName
add wave -noupdate -expand -group {Memory Stage} /testbench/dut/core/lsu/IEUAdrM
add wave -noupdate -expand -group lsu /testbench/dut/core/lsu/ReadDataM
add wave -noupdate -expand -group lsu /testbench/dut/core/lsu/WriteDataM
add wave -noupdate -expand -group lsu /testbench/dut/core/lsu/FWriteDataM
add wave -noupdate -expand -group lsu /testbench/dut/core/lsu/ReadDataWordMuxM
add wave -noupdate -expand -group lsu -group stalls /testbench/dut/core/lsu/bus/dcache/dcache/CacheStall
add wave -noupdate -expand -group lsu -group stalls /testbench/dut/core/lsu/SelHPTW
add wave -noupdate -expand -group lsu -group stalls /testbench/dut/core/lsu/LSUStallM
add wave -noupdate -expand -group lsu -group bus /testbench/dut/core/ebu/ebu/HCLK
add wave -noupdate -expand -group lsu -group bus -color Gold /testbench/dut/core/lsu/bus/dcache/ahbcacheinterface/AHBBuscachefsm/CurrState
add wave -noupdate -expand -group lsu -group bus /testbench/dut/core/lsu/bus/dcache/ahbcacheinterface/AHBBuscachefsm/HREADY
add wave -noupdate -expand -group lsu -group bus /testbench/dut/core/lsu/bus/dcache/ahbcacheinterface/HTRANS
add wave -noupdate -expand -group lsu -group bus /testbench/dut/core/lsu/bus/dcache/ahbcacheinterface/FetchBuffer
add wave -noupdate -expand -group lsu -group bus /testbench/dut/core/lsu/bus/dcache/ahbcacheinterface/HRDATA
add wave -noupdate -expand -group lsu -group bus /testbench/dut/core/lsu/LSUHWDATA
add wave -noupdate -expand -group lsu -group bus /testbench/dut/core/lsu/bus/dcache/ahbcacheinterface/CacheBusRW
add wave -noupdate -expand -group lsu -group bus /testbench/dut/core/lsu/bus/dcache/ahbcacheinterface/CacheBusAck
add wave -noupdate -expand -group lsu -group bus /testbench/dut/core/lsu/bus/dcache/dcache/CacheBusAdr
add wave -noupdate -expand -group lsu -group alignment /testbench/dut/core/lsu/ByteMaskM
add wave -noupdate -expand -group lsu -group alignment /testbench/dut/core/lsu/ByteMaskExtendedM
add wave -noupdate -expand -group lsu -group alignment /testbench/dut/core/lsu/ByteMaskSpillM
add wave -noupdate -expand -group lsu -group alignment /testbench/dut/core/lsu/LSUWriteDataM
add wave -noupdate -expand -group lsu -group alignment /testbench/dut/core/lsu/LSUWriteDataSpillM
add wave -noupdate -expand -group lsu -group alignment /testbench/dut/core/lsu/bus/dcache/dcache/WriteData
add wave -noupdate -expand -group lsu -group alignment /testbench/dut/core/lsu/bus/dcache/dcache/ByteMask
add wave -noupdate -expand -group lsu -group alignment /testbench/dut/core/lsu/bus/dcache/dcache/WriteSelLogic/BlankByteMask
add wave -noupdate -expand -group lsu -group alignment /testbench/dut/core/lsu/bus/dcache/dcache/WriteSelLogic/DemuxedByteMask
add wave -noupdate -expand -group lsu -group alignment /testbench/dut/core/lsu/bus/dcache/dcache/WriteSelLogic/FetchBufferByteSel
add wave -noupdate -expand -group lsu -group alignment {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[2]/LineWriteData}
add wave -noupdate -expand -group lsu /testbench/dut/core/lsu/IEUAdrExtE
add wave -noupdate -expand -group lsu /testbench/dut/core/lsu/IEUAdrExtM
add wave -noupdate -expand -group lsu /testbench/dut/core/lsu/bus/dcache/dcache/NextSet
add wave -noupdate -expand -group lsu -expand -group dcache /testbench/dut/core/lsu/bus/dcache/dcache/CacheRW
add wave -noupdate -expand -group lsu -expand -group dcache /testbench/dut/core/lsu/bus/dcache/dcache/CMOpM
add wave -noupdate -expand -group lsu -expand -group dcache -color Gold /testbench/dut/core/lsu/bus/dcache/dcache/cachefsm/CurrState
add wave -noupdate -expand -group lsu -expand -group dcache /testbench/dut/core/lsu/bus/dcache/dcache/Hit
add wave -noupdate -expand -group lsu -expand -group dcache -group SRAM-update-control /testbench/dut/core/lsu/bus/dcache/dcache/SetValid
add wave -noupdate -expand -group lsu -expand -group dcache -group SRAM-update-control /testbench/dut/core/lsu/bus/dcache/dcache/ClearValid
add wave -noupdate -expand -group lsu -expand -group dcache -group SRAM-update-control /testbench/dut/core/lsu/bus/dcache/dcache/SetDirty
add wave -noupdate -expand -group lsu -expand -group dcache -group SRAM-update-control /testbench/dut/core/lsu/bus/dcache/dcache/ClearDirty
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {requesting address} /testbench/dut/core/lsu/IEUAdrE
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {requesting address} /testbench/dut/core/lsu/bus/dcache/dcache/PAdr
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {requesting address} {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[1]/CacheSetTag}
add wave -noupdate -expand -group lsu -expand -group dcache -group SRAM-outputs /testbench/dut/core/lsu/bus/dcache/dcache/ReadDataLineWay
add wave -noupdate -expand -group lsu -expand -group dcache -group SRAM-outputs /testbench/dut/core/lsu/bus/dcache/dcache/ReadDataLineCache
add wave -noupdate -expand -group lsu -expand -group dcache -group SRAM-outputs /testbench/dut/core/lsu/bus/dcache/dcache/TagWay
add wave -noupdate -expand -group lsu -expand -group dcache -group SRAM-outputs /testbench/dut/core/lsu/bus/dcache/dcache/Tag
add wave -noupdate -expand -group lsu -expand -group dcache -group SRAM-outputs /testbench/dut/core/lsu/bus/dcache/dcache/ValidWay
add wave -noupdate -expand -group lsu -expand -group dcache -group SRAM-outputs /testbench/dut/core/lsu/bus/dcache/dcache/HitWay
add wave -noupdate -expand -group lsu -expand -group dcache -group SRAM-outputs -color {Blue Violet} /testbench/dut/core/lsu/bus/dcache/dcache/Hit
add wave -noupdate -expand -group lsu -expand -group dcache -group SRAM-outputs /testbench/dut/core/lsu/bus/dcache/dcache/DirtyWay
add wave -noupdate -expand -group lsu -expand -group dcache -group SRAM-outputs {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[0]/Dirty}
add wave -noupdate -expand -group lsu -expand -group dcache -group SRAM-outputs /testbench/dut/core/lsu/bus/dcache/dcache/HitDirtyWay
add wave -noupdate -expand -group lsu -expand -group dcache -group SRAM-outputs /testbench/dut/core/lsu/bus/dcache/dcache/HitLineDirty
add wave -noupdate -expand -group lsu -expand -group dcache /testbench/dut/core/lsu/bus/dcache/dcache/SelWriteback
add wave -noupdate -expand -group lsu -expand -group dcache /testbench/dut/core/lsu/bus/dcache/dcache/ReadDataWord
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {replacement policy} /testbench/dut/core/lsu/bus/dcache/dcache/vict/cacheLRU/HitWay
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {replacement policy} /testbench/dut/core/lsu/bus/dcache/dcache/vict/cacheLRU/LRUWriteEn
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {replacement policy} -color {Orange Red} {/testbench/dut/core/lsu/bus/dcache/dcache/vict/cacheLRU/LRUMemory[0]}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {replacement policy} /testbench/dut/core/lsu/bus/dcache/dcache/vict/cacheLRU/CurrLRU
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {replacement policy} /testbench/dut/core/lsu/bus/dcache/dcache/vict/cacheLRU/NextLRU
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {replacement policy} /testbench/dut/core/lsu/bus/dcache/dcache/vict/cacheLRU/VictimWay
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {replacement policy} -group DETAILS -expand /testbench/dut/core/lsu/bus/dcache/dcache/vict/cacheLRU/Intermediate
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {replacement policy} -group DETAILS /testbench/dut/core/lsu/bus/dcache/dcache/vict/cacheLRU/LRUUpdate
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {replacement policy} -group DETAILS /testbench/dut/core/lsu/bus/dcache/dcache/vict/cacheLRU/WayExpanded
add wave -noupdate -expand -group lsu -expand -group dcache -group flush /testbench/dut/core/lsu/bus/dcache/dcache/LineDirty
add wave -noupdate -expand -group lsu -expand -group dcache -group flush /testbench/dut/core/lsu/bus/dcache/dcache/FlushWay
add wave -noupdate -expand -group lsu -expand -group dcache -group flush -radix hexadecimal /testbench/dut/core/lsu/bus/dcache/dcache/FlushAdr
add wave -noupdate -expand -group lsu -expand -group dcache -group flush /testbench/dut/core/lsu/bus/dcache/dcache/cachefsm/FlushWayFlag
add wave -noupdate -expand -group lsu -expand -group dcache -group flush /testbench/dut/core/lsu/bus/dcache/dcache/FlushWayCntEn
add wave -noupdate -expand -group lsu -expand -group dcache -group flush /testbench/dut/core/lsu/bus/dcache/dcache/cachefsm/FlushAdrCntEn
add wave -noupdate -expand -group lsu -expand -group dcache -group flush /testbench/dut/core/lsu/bus/dcache/dcache/FlushAdrFlag
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} /testbench/dut/core/lsu/bus/dcache/dcache/SetValid
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} /testbench/dut/core/lsu/bus/dcache/dcache/ClearValid
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} /testbench/dut/core/lsu/bus/dcache/dcache/SetDirty
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} /testbench/dut/core/lsu/bus/dcache/dcache/ClearDirty
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} /testbench/dut/core/lsu/bus/dcache/dcache/LineByteMask
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[0]/CacheSetData}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[0]/CacheSetTag}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -expand -group way0 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[0]/SelectedWriteWordEn}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -expand -group way0 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[0]/SetValidWay}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -expand -group way0 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[0]/ClearValidWay}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -expand -group way0 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[0]/SetDirtyWay}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -expand -group way0 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[0]/ClearDirtyWay}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -expand -group way0 -label TAG {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[0]/CacheTagMem/ram/RAM}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -expand -group way0 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[0]/ValidBits}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -expand -group way0 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[0]/DirtyBits}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -expand -group way0 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[0]/Dirty}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -expand -group way0 -expand -group Way0Word0 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[0]/word[0]/wordram/CacheDataMem/we}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -expand -group way0 -expand -group Way0Word0 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[0]/word[0]/wordram/CacheDataMem/bwe}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -expand -group way0 -expand -group Way0Word0 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[0]/word[0]/wordram/CacheDataMem/ram/RAM}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -expand -group way0 -expand -group Way0Word1 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[0]/word[1]/wordram/CacheDataMem/we}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -expand -group way0 -expand -group Way0Word1 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[0]/word[1]/wordram/CacheDataMem/bwe}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -expand -group way0 -expand -group Way0Word1 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[0]/word[1]/wordram/CacheDataMem/ram/RAM}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -expand -group way0 -expand -group Way0Word2 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[0]/word[2]/wordram/CacheDataMem/we}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -expand -group way0 -expand -group Way0Word2 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[0]/word[2]/wordram/CacheDataMem/bwe}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -expand -group way0 -expand -group Way0Word2 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[0]/word[2]/wordram/CacheDataMem/ram/RAM}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -expand -group way0 -expand -group Way0Word3 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[0]/word[3]/wordram/CacheDataMem/ce}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -expand -group way0 -expand -group Way0Word3 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[0]/word[3]/wordram/CacheDataMem/we}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -expand -group way0 -expand -group Way0Word3 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[0]/word[3]/wordram/CacheDataMem/bwe}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -expand -group way0 -expand -group Way0Word3 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[0]/word[3]/wordram/CacheDataMem/ram/RAM}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way1 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[1]/SelectedWriteWordEn}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way1 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[1]/SetValidWay}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way1 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[1]/ClearValidWay}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way1 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[1]/SetDirtyWay}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way1 -label TAG {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[1]/CacheTagMem/ram/RAM}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way1 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[1]/ValidBits}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way1 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[1]/DirtyBits}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way1 -group Way1Word0 -expand {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[1]/word[0]/wordram/CacheDataMem/ram/RAM}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way1 -group Way1Word0 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[1]/word[0]/wordram/CacheDataMem/we}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way1 -group Way1Word1 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[1]/word[1]/wordram/CacheDataMem/ram/RAM}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way1 -group Way1Word1 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[1]/word[1]/wordram/CacheDataMem/we}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way1 -group Way1Word2 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[1]/word[2]/wordram/CacheDataMem/we}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way1 -group Way1Word2 -expand {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[1]/word[2]/wordram/CacheDataMem/ram/RAM}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way1 -group Way1Word3 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[1]/word[3]/wordram/CacheDataMem/we}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way1 -group Way1Word3 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[1]/word[3]/wordram/CacheDataMem/ram/RAM}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way2 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[2]/SelectedWriteWordEn}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way2 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[2]/SetValidWay}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way2 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[2]/ClearValidWay}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way2 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[2]/SetDirtyWay}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way2 -label TAG {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[2]/CacheTagMem/ram/RAM}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way2 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[2]/ValidBits}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way2 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[2]/DirtyBits}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way2 -group Way2Word0 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[2]/word[0]/wordram/CacheDataMem/ram/RAM}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way2 -group Way2Word0 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[2]/word[0]/wordram/CacheDataMem/we}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way2 -group Way2Word1 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[2]/word[1]/wordram/CacheDataMem/ram/RAM}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way2 -group Way2Word1 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[2]/word[1]/wordram/CacheDataMem/we}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way2 -group Way2Word2 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[2]/word[2]/wordram/CacheDataMem/we}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way2 -group Way2Word2 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[2]/word[2]/wordram/CacheDataMem/ram/RAM}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way2 -group Way2Word3 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[2]/word[3]/wordram/CacheDataMem/we}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way2 -group Way2Word3 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[2]/word[3]/wordram/CacheDataMem/ram/RAM}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way3 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[3]/SelectedWriteWordEn}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way3 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[3]/SetValidWay}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way3 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[3]/ClearValidWay}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way3 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[3]/SetDirtyWay}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way3 -label TAG {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[3]/CacheTagMem/ram/RAM}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way3 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[3]/ValidBits}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way3 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[3]/DirtyBits}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way3 -group Way3Word0 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[3]/word[0]/wordram/CacheDataMem/ram/RAM}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way3 -group Way3Word0 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[3]/word[0]/wordram/CacheDataMem/we}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way3 -group Way3Word1 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[3]/word[1]/wordram/CacheDataMem/ram/RAM}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way3 -group Way3Word1 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[3]/word[1]/wordram/CacheDataMem/we}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way3 -group Way3Word2 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[3]/word[2]/wordram/CacheDataMem/we}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way3 -group Way3Word2 -expand {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[3]/word[2]/wordram/CacheDataMem/ram/RAM}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way3 -group Way3Word3 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[3]/word[3]/wordram/CacheDataMem/we}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group way3 -group Way3Word3 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[3]/word[3]/wordram/CacheDataMem/ram/RAM}
add wave -noupdate -expand -group lsu -expand -group dcache -expand -group {Cache SRAM writes} -group valid/dirty /testbench/dut/core/lsu/bus/dcache/dcache/ClearDirty
add wave -noupdate -expand -group lsu -expand -group dcache -group {Cache SRAM read} -expand -group way0 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[0]/HitWay}
add wave -noupdate -expand -group lsu -expand -group dcache -group {Cache SRAM read} -expand -group way0 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[0]/ValidWay}
add wave -noupdate -expand -group lsu -expand -group dcache -group {Cache SRAM read} -expand -group way0 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[0]/Dirty}
add wave -noupdate -expand -group lsu -expand -group dcache -group {Cache SRAM read} -expand -group way0 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[0]/ReadTag}
add wave -noupdate -expand -group lsu -expand -group dcache -group {Cache SRAM read} -expand -group way0 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[0]/TagWay}
add wave -noupdate -expand -group lsu -expand -group dcache -group {Cache SRAM read} -expand -group way1 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[1]/HitWay}
add wave -noupdate -expand -group lsu -expand -group dcache -group {Cache SRAM read} -expand -group way1 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[1]/ValidWay}
add wave -noupdate -expand -group lsu -expand -group dcache -group {Cache SRAM read} -expand -group way1 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[1]/Dirty}
add wave -noupdate -expand -group lsu -expand -group dcache -group {Cache SRAM read} -expand -group way1 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[1]/ReadTag}
add wave -noupdate -expand -group lsu -expand -group dcache -group {Cache SRAM read} -expand -group way1 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[1]/TagWay}
add wave -noupdate -expand -group lsu -expand -group dcache -group {Cache SRAM read} -group way2 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[2]/HitWay}
add wave -noupdate -expand -group lsu -expand -group dcache -group {Cache SRAM read} -group way2 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[2]/ValidWay}
add wave -noupdate -expand -group lsu -expand -group dcache -group {Cache SRAM read} -group way2 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[2]/Dirty}
add wave -noupdate -expand -group lsu -expand -group dcache -group {Cache SRAM read} -group way2 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[2]/ReadTag}
add wave -noupdate -expand -group lsu -expand -group dcache -group {Cache SRAM read} -group way2 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[2]/TagWay}
add wave -noupdate -expand -group lsu -expand -group dcache -group {Cache SRAM read} -group way3 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[3]/HitWay}
add wave -noupdate -expand -group lsu -expand -group dcache -group {Cache SRAM read} -group way3 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[3]/ValidWay}
add wave -noupdate -expand -group lsu -expand -group dcache -group {Cache SRAM read} -group way3 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[3]/Dirty}
add wave -noupdate -expand -group lsu -expand -group dcache -group {Cache SRAM read} -group way3 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[3]/ReadTag}
add wave -noupdate -expand -group lsu -expand -group dcache -group {Cache SRAM read} -group way3 {/testbench/dut/core/lsu/bus/dcache/dcache/CacheWays[3]/TagWay}
add wave -noupdate -expand -group lsu -group dtlb /testbench/dut/core/lsu/dmmu/dmmu/tlb/tlb/VAdr
add wave -noupdate -expand -group lsu -group dtlb /testbench/dut/core/lsu/dmmu/dmmu/tlb/tlb/PTE
add wave -noupdate -expand -group lsu -group dtlb /testbench/dut/core/lsu/dmmu/dmmu/tlb/tlb/HitPageType
add wave -noupdate -expand -group lsu -group dtlb /testbench/dut/core/lsu/dmmu/dmmu/tlb/tlb/tlbcontrol/Translate
add wave -noupdate -expand -group lsu -group dtlb /testbench/dut/core/lsu/dmmu/dmmu/tlb/tlb/tlbcontrol/DisableTranslation
add wave -noupdate -expand -group lsu -group dtlb /testbench/dut/core/lsu/dmmu/dmmu/TLBMiss
add wave -noupdate -expand -group lsu -group dtlb /testbench/dut/core/lsu/dmmu/dmmu/tlb/tlb/TLBHit
add wave -noupdate -expand -group lsu -group dtlb /testbench/dut/core/lsu/dmmu/dmmu/PhysicalAddress
add wave -noupdate -expand -group lsu -group dtlb -expand -group faults /testbench/dut/core/lsu/dmmu/dmmu/TLBPageFault
add wave -noupdate -expand -group lsu -group dtlb -expand -group faults /testbench/dut/core/lsu/dmmu/dmmu/LoadAccessFaultM
add wave -noupdate -expand -group lsu -group dtlb -expand -group faults /testbench/dut/core/lsu/dmmu/dmmu/StoreAmoAccessFaultM
add wave -noupdate -expand -group lsu -group dtlb /testbench/dut/core/lsu/dmmu/dmmu/tlb/tlb/TLBPAdr
add wave -noupdate -expand -group lsu -group dtlb -expand -group write /testbench/dut/core/lsu/dmmu/dmmu/tlb/tlb/PTE
add wave -noupdate -expand -group lsu -group dtlb -expand -group write /testbench/dut/core/lsu/dmmu/dmmu/tlb/tlb/PageTypeWriteVal
add wave -noupdate -expand -group lsu -group dtlb -expand -group write /testbench/dut/core/lsu/dmmu/dmmu/tlb/tlb/TLBWrite
add wave -noupdate -expand -group lsu -group pma /testbench/dut/core/lsu/dmmu/dmmu/pmachecker/PhysicalAddress
add wave -noupdate -expand -group lsu -group pma /testbench/dut/core/lsu/dmmu/dmmu/pmachecker/SelRegions
add wave -noupdate -expand -group lsu -group pma /testbench/dut/core/lsu/dmmu/dmmu/Cacheable
add wave -noupdate -expand -group lsu -group pma /testbench/dut/core/lsu/dmmu/dmmu/Idempotent
add wave -noupdate -expand -group lsu -group pma /testbench/dut/core/lsu/dmmu/dmmu/pmachecker/PMAAccessFault
add wave -noupdate -expand -group lsu -group pma /testbench/dut/core/lsu/dmmu/dmmu/PMAInstrAccessFaultF
add wave -noupdate -expand -group lsu -group pma /testbench/dut/core/lsu/dmmu/dmmu/PMALoadAccessFaultM
add wave -noupdate -expand -group lsu -group pma /testbench/dut/core/lsu/dmmu/dmmu/PMAStoreAmoAccessFaultM
add wave -noupdate -expand -group lsu -group pmp /testbench/dut/core/lsu/dmmu/dmmu/PMPInstrAccessFaultF
add wave -noupdate -expand -group lsu -group pmp /testbench/dut/core/lsu/dmmu/dmmu/PMPLoadAccessFaultM
add wave -noupdate -expand -group lsu -group pmp /testbench/dut/core/lsu/dmmu/dmmu/PMPStoreAmoAccessFaultM
add wave -noupdate -expand -group lsu -group ptwalker /testbench/dut/core/lsu/hptw/hptw/SelHPTW
add wave -noupdate -expand -group lsu -group ptwalker /testbench/dut/core/lsu/hptw/hptw/HPTWStall
add wave -noupdate -expand -group lsu -group ptwalker /testbench/dut/core/lsu/hptw/hptw/DTLBWalk
add wave -noupdate -expand -group lsu -group ptwalker -color Gold /testbench/dut/core/lsu/hptw/hptw/WalkerState
add wave -noupdate -expand -group lsu -group ptwalker /testbench/dut/core/lsu/hptw/hptw/NextWalkerState
add wave -noupdate -expand -group lsu -group ptwalker /testbench/dut/core/lsu/hptw/hptw/HPTWAdr
add wave -noupdate -expand -group lsu -group ptwalker /testbench/dut/core/lsu/hptw/hptw/PTE
add wave -noupdate -expand -group lsu -group ptwalker /testbench/dut/core/lsu/hptw/hptw/NextPageType
add wave -noupdate -expand -group lsu -group ptwalker /testbench/dut/core/lsu/hptw/hptw/PageType
add wave -noupdate -expand -group lsu -group ptwalker /testbench/dut/core/lsu/hptw/hptw/ValidNonLeafPTE
add wave -noupdate -expand -group lsu -group ptwalker /testbench/dut/core/lsu/hptw/hptw/TranslationVAdr
add wave -noupdate -expand -group lsu -group ptwalker -expand -group types /testbench/dut/core/lsu/DTLBMissM
add wave -noupdate -expand -group lsu -group ptwalker -expand -group types /testbench/dut/core/lsu/hptw/hptw/DTLBWriteM
add wave -noupdate -expand -group lsu -group ptwalker -expand -group types /testbench/dut/core/lsu/hptw/hptw/ITLBMissOrUpdateAF
add wave -noupdate -expand -group lsu -group ptwalker -expand -group types /testbench/dut/core/lsu/hptw/hptw/ITLBWriteF
add wave -noupdate -expand -group lsu -group ptwalker -expand -group faults /testbench/dut/core/lsu/hptw/hptw/HPTWFaultM
add wave -noupdate -expand -group lsu -group ptwalker -expand -group faults /testbench/dut/core/lsu/hptw/hptw/LSUAccessFaultM
add wave -noupdate -expand -group lsu -group ptwalker -expand -group faults /testbench/dut/core/lsu/hptw/hptw/HPTWInstrAccessFaultF
add wave -noupdate -expand -group lsu -group ptwalker -expand -group faults /testbench/dut/core/lsu/hptw/hptw/LSULoadAccessFaultM
add wave -noupdate -expand -group lsu -group ptwalker -expand -group faults /testbench/dut/core/lsu/hptw/hptw/LSUStoreAmoAccessFaultM
add wave -noupdate -expand -group lsu -group ptwalker -expand -group faults /testbench/dut/core/lsu/hptw/hptw/LoadAccessFaultM
add wave -noupdate -expand -group lsu -group ptwalker -expand -group faults /testbench/dut/core/lsu/hptw/hptw/StoreAmoAccessFaultM
add wave -noupdate -expand -group lsu -group ptwalker -expand -group faults /testbench/dut/core/lsu/hptw/hptw/HPTWInstrAccessFault
add wave -noupdate -expand -group lsu -group ptwalker -expand -group faults /testbench/dut/core/lsu/hptw/hptw/PBMTFaultM
add wave -noupdate -group {WriteBack stage} /testbench/InstrW
add wave -noupdate -group {WriteBack stage} /testbench/InstrWName
add wave -noupdate -group {WriteBack stage} /testbench/dut/core/priv/priv/pmd/wfiW
add wave -noupdate -group AHB -group multicontroller /testbench/dut/core/ebu/ebu/IFUReq
add wave -noupdate -group AHB -group multicontroller /testbench/dut/core/ebu/ebu/LSUReq
add wave -noupdate -group AHB -group multicontroller /testbench/dut/core/ebu/ebu/IFUSave
add wave -noupdate -group AHB -group multicontroller /testbench/dut/core/ebu/ebu/IFURestore
add wave -noupdate -group AHB -group multicontroller /testbench/dut/core/ebu/ebu/IFUDisable
add wave -noupdate -group AHB -group multicontroller /testbench/dut/core/ebu/ebu/LSUDisable
add wave -noupdate -group AHB -group multicontroller /testbench/dut/core/ebu/ebu/IFUSelect
add wave -noupdate -group AHB -group multicontroller /testbench/dut/core/ebu/ebu/LSUSelect
add wave -noupdate -group AHB -group multicontroller /testbench/dut/core/ebu/ebu/ebufsmarb/CurrState
add wave -noupdate -group AHB /testbench/dut/core/ebu/ebu/HTRANS
add wave -noupdate -group AHB /testbench/dut/core/ebu/ebu/HBURST
add wave -noupdate -group AHB -group IFU /testbench/dut/core/ebu/ebu/IFUHTRANS
add wave -noupdate -group AHB -group IFU /testbench/dut/core/ebu/ebu/IFUHADDR
add wave -noupdate -group AHB -group IFU /testbench/dut/core/ebu/ebu/IFUHBURST
add wave -noupdate -group AHB -group IFU /testbench/dut/core/ebu/ebu/IFUHREADY
add wave -noupdate -group AHB -group IFU /testbench/dut/core/HRDATA
add wave -noupdate -group AHB -group LSU /testbench/dut/core/ebu/ebu/LSUReq
add wave -noupdate -group AHB -group LSU /testbench/dut/core/ebu/ebu/LSUHTRANS
add wave -noupdate -group AHB -group LSU /testbench/dut/core/ebu/ebu/LSUHSIZE
add wave -noupdate -group AHB -group LSU /testbench/dut/core/ebu/ebu/LSUHBURST
add wave -noupdate -group AHB -group LSU /testbench/dut/core/ebu/ebu/LSUHADDR
add wave -noupdate -group AHB -group LSU /testbench/dut/core/HRDATA
add wave -noupdate -group AHB -group LSU /testbench/dut/core/ebu/ebu/LSUHWRITE
add wave -noupdate -group AHB -group LSU /testbench/dut/core/ebu/ebu/LSUHWSTRB
add wave -noupdate -group AHB -group LSU /testbench/dut/core/ebu/ebu/LSUHWDATA
add wave -noupdate -group AHB -group LSU -color Pink /testbench/dut/core/lsu/LSUHREADY
add wave -noupdate -group AHB /testbench/dut/core/ebu/ebu/HCLK
add wave -noupdate -group AHB /testbench/dut/core/ebu/ebu/HRESETn
add wave -noupdate -group AHB /testbench/dut/core/ebu/ebu/HREADY
add wave -noupdate -group AHB /testbench/dut/core/ebu/ebu/HRESP
add wave -noupdate -group AHB /testbench/dut/core/ebu/ebu/HADDR
add wave -noupdate -group AHB /testbench/dut/core/HRDATA
add wave -noupdate -group AHB /testbench/dut/core/ebu/ebu/HWDATA
add wave -noupdate -group AHB /testbench/dut/core/ebu/ebu/HWRITE
add wave -noupdate -group AHB /testbench/dut/core/ebu/ebu/HSIZE
add wave -noupdate -group AHB /testbench/dut/core/ebu/ebu/HBURST
add wave -noupdate -group AHB /testbench/dut/core/ebu/ebu/HPROT
add wave -noupdate -group AHB /testbench/dut/core/ebu/ebu/HTRANS
add wave -noupdate -group AHB /testbench/dut/core/ebu/ebu/HMASTLOCK
add wave -noupdate -group uncore /testbench/dut/uncoregen/uncore/HADDR
add wave -noupdate -group uncore /testbench/dut/uncoregen/uncore/HTRANS
add wave -noupdate -group uncore /testbench/dut/uncoregen/uncore/HREADY
add wave -noupdate -group uncore /testbench/dut/uncoregen/uncore/HSELRegions
add wave -noupdate -group uncore /testbench/dut/uncoregen/uncore/HSELNoneD
add wave -noupdate -group uncore /testbench/dut/uncoregen/uncore/HSELPLICD
add wave -noupdate -group uncore /testbench/dut/uncoregen/uncore/HRDATA
add wave -noupdate -group uncore -group plic /testbench/dut/uncoregen/uncore/plic/plic/UARTIntr
add wave -noupdate -group uncore -group plic /testbench/dut/uncoregen/uncore/plic/plic/GPIOIntr
add wave -noupdate -group uncore -group plic /testbench/dut/uncoregen/uncore/plic/plic/MExtInt
add wave -noupdate -group uncore -group plic /testbench/dut/uncoregen/uncore/plic/plic/SExtInt
add wave -noupdate -group uncore -group plic /testbench/dut/uncoregen/uncore/plic/plic/Dout
add wave -noupdate -group uncore -group plic -expand -group internals /testbench/dut/uncoregen/uncore/plic/plic/intClaim
add wave -noupdate -group uncore -group plic -expand -group internals /testbench/dut/uncoregen/uncore/plic/plic/intEn
add wave -noupdate -group uncore -group plic -expand -group internals /testbench/dut/uncoregen/uncore/plic/plic/intInProgress
add wave -noupdate -group uncore -group plic -expand -group internals /testbench/dut/uncoregen/uncore/plic/plic/intPending
add wave -noupdate -group uncore -group plic -expand -group internals /testbench/dut/uncoregen/uncore/plic/plic/intPriority
add wave -noupdate -group uncore -group plic -expand -group internals /testbench/dut/uncoregen/uncore/plic/plic/intThreshold
add wave -noupdate -group uncore -group plic -expand -group internals /testbench/dut/uncoregen/uncore/plic/plic/nextIntPending
add wave -noupdate -group uncore -group plic -expand -group internals /testbench/dut/uncoregen/uncore/plic/plic/requests
add wave -noupdate -group uncore -group plic -expand -group internals /testbench/dut/uncoregen/uncore/plic/plic/irqMatrix
add wave -noupdate -group uncore -group plic -expand -group internals /testbench/dut/uncoregen/uncore/plic/plic/priorities_with_irqs
add wave -noupdate -group uncore -group plic -expand -group internals /testbench/dut/uncoregen/uncore/plic/plic/max_priority_with_irqs
add wave -noupdate -group uncore -group plic -expand -group internals /testbench/dut/uncoregen/uncore/plic/plic/irqs_at_max_priority
add wave -noupdate -group uncore -group plic -expand -group internals /testbench/dut/uncoregen/uncore/plic/plic/threshMask
add wave -noupdate -group uncore -group CLINT /testbench/dut/uncoregen/uncore/clint/clint/MTIME
add wave -noupdate -group uncore -group CLINT /testbench/dut/uncoregen/uncore/clint/clint/MTIMECMP
add wave -noupdate -group uncore -group CLINT -expand -group {clint bus} /testbench/dut/uncoregen/uncore/clint/clint/PSEL
add wave -noupdate -group uncore -group CLINT -expand -group {clint bus} /testbench/dut/uncoregen/uncore/clint/clint/PADDR
add wave -noupdate -group uncore -group CLINT -expand -group {clint bus} /testbench/dut/uncoregen/uncore/clint/clint/PWDATA
add wave -noupdate -group uncore -group CLINT -expand -group {clint bus} /testbench/dut/uncoregen/uncore/clint/clint/PSTRB
add wave -noupdate -group uncore -group CLINT -expand -group {clint bus} /testbench/dut/uncoregen/uncore/clint/clint/PWRITE
add wave -noupdate -group uncore -group CLINT -expand -group {clint bus} /testbench/dut/uncoregen/uncore/clint/clint/PENABLE
add wave -noupdate -group uncore -group CLINT -expand -group {clint bus} /testbench/dut/uncoregen/uncore/clint/clint/PRDATA
add wave -noupdate -group uncore -group CLINT -expand -group {clint bus} /testbench/dut/uncoregen/uncore/clint/clint/PREADY
add wave -noupdate -group uncore -group uart -expand -group Registers /testbench/dut/uncoregen/uncore/uartgen/uart/uartPC/LSR
add wave -noupdate -group uncore -group uart -expand -group Registers /testbench/dut/uncoregen/uncore/uartgen/uart/uartPC/MCR
add wave -noupdate -group uncore -group uart -expand -group Registers /testbench/dut/uncoregen/uncore/uartgen/uart/uartPC/MSR
add wave -noupdate -group uncore -group uart -expand -group Registers /testbench/dut/uncoregen/uncore/uartgen/uart/uartPC/RBR
add wave -noupdate -group uncore -group uart -expand -group Registers /testbench/dut/uncoregen/uncore/uartgen/uart/uartPC/TXHR
add wave -noupdate -group uncore -group uart -expand -group Registers /testbench/dut/uncoregen/uncore/uartgen/uart/uartPC/LCR
add wave -noupdate -group uncore -group uart /testbench/dut/uncoregen/uncore/uartgen/uart/uartPC/intrID
add wave -noupdate -group uncore -group uart /testbench/dut/uncoregen/uncore/uartgen/uart/INTR
add wave -noupdate -group uncore -group uart /testbench/dut/uncoregen/uncore/uartgen/uart/uartPC/rxstate
add wave -noupdate -group uncore -group uart /testbench/dut/uncoregen/uncore/uartgen/uart/uartPC/txstate
add wave -noupdate -group uncore -group uart /testbench/dut/uncoregen/uncore/uartgen/uart/uartPC/txbitssent
add wave -noupdate -group uncore -group uart /testbench/dut/uncoregen/uncore/uartgen/uart/uartPC/txbitsexpected
add wave -noupdate -group uncore -group uart /testbench/dut/uncoregen/uncore/uartgen/uart/uartPC/rxbitsreceived
add wave -noupdate -group uncore -group uart /testbench/dut/uncoregen/uncore/uartgen/uart/uartPC/rxbitsexpected
add wave -noupdate -group uncore -group uart /testbench/dut/uncoregen/uncore/uartgen/uart/uartPC/rxdata
add wave -noupdate -group uncore -group uart /testbench/dut/uncoregen/uncore/uartgen/uart/uartPC/rxoverrunerr
add wave -noupdate -group uncore -group uart /testbench/dut/uncoregen/uncore/uartgen/uart/uartPC/rxdataready
add wave -noupdate -group uncore -group uart /testbench/dut/uncoregen/uncore/uartgen/uart/uartPC/rxdataavailintr
add wave -noupdate -group uncore -group uart /testbench/dut/uncoregen/uncore/uartgen/uart/uartPC/RXBR
add wave -noupdate -group uncore -group uart /testbench/dut/uncoregen/uncore/uartgen/uart/uartPC/squashRXerrIP
add wave -noupdate -group uncore -group uart /testbench/dut/uncoregen/uncore/uartgen/uart/uartPC/rxshiftreg
add wave -noupdate -group uncore -group uart /testbench/dut/uncoregen/uncore/uartgen/uart/uartPC/SOUTbit
add wave -noupdate -group uncore -group uart /testbench/dut/uncoregen/uncore/uartgen/uart/uartPC/SINsync
add wave -noupdate -group uncore -group uart /testbench/dut/uncoregen/uncore/uartgen/uart/uartPC/txsr
add wave -noupdate -group uncore -group uart -expand -group {Off-Chip Interface} /testbench/dut/uncoregen/uncore/uartgen/uart/SIN
add wave -noupdate -group uncore -group uart -expand -group {Off-Chip Interface} /testbench/dut/uncoregen/uncore/uartgen/uart/SOUT
add wave -noupdate -group uncore -group uart -expand -group {Off-Chip Interface} /testbench/dut/uncoregen/uncore/uartgen/uart/RTSb
add wave -noupdate -group uncore -group uart -expand -group {Off-Chip Interface} /testbench/dut/uncoregen/uncore/uartgen/uart/DTRb
add wave -noupdate -group uncore -group uart -expand -group {Off-Chip Interface} /testbench/dut/uncoregen/uncore/uartgen/uart/OUT1b
add wave -noupdate -group uncore -group uart -expand -group {Off-Chip Interface} /testbench/dut/uncoregen/uncore/uartgen/uart/OUT2b
add wave -noupdate -group uncore -group uart -expand -group {Off-Chip Interface} /testbench/dut/uncoregen/uncore/uartgen/uart/DSRb
add wave -noupdate -group uncore -group uart -expand -group {Off-Chip Interface} /testbench/dut/uncoregen/uncore/uartgen/uart/DCDb
add wave -noupdate -group uncore -group uart -expand -group {Off-Chip Interface} /testbench/dut/uncoregen/uncore/uartgen/uart/CTSb
add wave -noupdate -group uncore -group uart -expand -group {Off-Chip Interface} /testbench/dut/uncoregen/uncore/uartgen/uart/TXRDYb
add wave -noupdate -group uncore -group uart -expand -group {Off-Chip Interface} /testbench/dut/uncoregen/uncore/uartgen/uart/RXRDYb
add wave -noupdate -group uncore -group GPIO /testbench/dut/uncoregen/uncore/gpio/gpio/GPIOIN
add wave -noupdate -group uncore -group GPIO /testbench/dut/uncoregen/uncore/gpio/gpio/GPIOOUT
add wave -noupdate -group uncore -group GPIO /testbench/dut/uncoregen/uncore/gpio/gpio/GPIOEN
add wave -noupdate -group uncore -group GPIO /testbench/dut/uncoregen/uncore/gpio/gpio/GPIOIntr
add wave -noupdate -group uncore -group GPIO /testbench/dut/uncoregen/uncore/gpio/gpio/PSEL
add wave -noupdate -group uncore -group GPIO /testbench/dut/uncoregen/uncore/gpio/gpio/PADDR
add wave -noupdate -group uncore -group GPIO /testbench/dut/uncoregen/uncore/gpio/gpio/PWRITE
add wave -noupdate -group uncore -group GPIO /testbench/dut/uncoregen/uncore/gpio/gpio/PRDATA
add wave -noupdate -group uncore -group GPIO /testbench/dut/uncoregen/uncore/gpio/gpio/PREADY
add wave -noupdate -group uncore -group GPIO /testbench/dut/uncoregen/uncore/gpio/gpio/PWDATA
add wave -noupdate -group uncore -group GPIO /testbench/dut/uncoregen/uncore/gpio/gpio/PSTRB
add wave -noupdate -group uncore -group GPIO /testbench/dut/uncoregen/uncore/gpio/gpio/PENABLE
add wave -noupdate -group RegFile /testbench/dut/core/ieu/dp/regf/rf
add wave -noupdate -group RegFile /testbench/dut/core/ieu/dp/regf/a1
add wave -noupdate -group RegFile /testbench/dut/core/ieu/dp/regf/a2
add wave -noupdate -group RegFile /testbench/dut/core/ieu/dp/regf/a3
add wave -noupdate -group RegFile /testbench/dut/core/ieu/dp/regf/rd1
add wave -noupdate -group RegFile /testbench/dut/core/ieu/dp/regf/rd2
add wave -noupdate -group RegFile /testbench/dut/core/ieu/dp/regf/we3
add wave -noupdate -group RegFile /testbench/dut/core/ieu/dp/regf/wd3
add wave -noupdate -group RegFile -group {write regfile mux} /testbench/dut/core/ieu/dp/ReadDataW
add wave -noupdate -group RegFile -group {write regfile mux} /testbench/dut/core/ieu/dp/CSRReadValW
add wave -noupdate -group RegFile -group {write regfile mux} /testbench/dut/core/ieu/dp/ResultSrcW
add wave -noupdate -group RegFile -group {write regfile mux} /testbench/dut/core/ieu/dp/ResultW
add wave -noupdate -group CSRs /testbench/dut/core/priv/priv/csr/csrm/MISA_REGW
add wave -noupdate -group CSRs /testbench/dut/core/priv/priv/csr/csrm/MCAUSE_REGW
add wave -noupdate -group CSRs /testbench/dut/core/priv/priv/csr/MCOUNTEREN_REGW
add wave -noupdate -group CSRs /testbench/dut/core/priv/priv/csr/MCOUNTINHIBIT_REGW
add wave -noupdate -group CSRs /testbench/dut/core/priv/priv/csr/MEDELEG_REGW
add wave -noupdate -group CSRs /testbench/dut/core/priv/priv/csr/MEPC_REGW
add wave -noupdate -group CSRs /testbench/dut/core/priv/priv/csr/MIDELEG_REGW
add wave -noupdate -group CSRs /testbench/dut/core/priv/priv/csr/MIE_REGW
add wave -noupdate -group CSRs /testbench/dut/core/priv/priv/csr/MIP_REGW
add wave -noupdate -group CSRs {/testbench/dut/core/priv/priv/csr/MSTATUS_REGW[21]}
add wave -noupdate -group CSRs /testbench/dut/core/priv/priv/csr/MSTATUS_REGW
add wave -noupdate -group CSRs /testbench/dut/core/priv/priv/csr/MTVEC_REGW
add wave -noupdate -group CSRs /testbench/dut/core/priv/priv/csr/csrm/MENVCFG_REGW
add wave -noupdate -group CSRs /testbench/dut/core/priv/priv/csr/PMPADDR_ARRAY_REGW
add wave -noupdate -group CSRs /testbench/dut/core/priv/priv/csr/PMPCFG_ARRAY_REGW
add wave -noupdate -group CSRs /testbench/dut/core/priv/priv/csr/SATP_REGW
add wave -noupdate -group CSRs /testbench/dut/core/priv/priv/privmode/PrivilegeModeW
add wave -noupdate -group CSRs /testbench/dut/core/priv/priv/csr/SCOUNTEREN_REGW
add wave -noupdate -group CSRs /testbench/dut/core/priv/priv/csr/SEPC_REGW
add wave -noupdate -group CSRs /testbench/dut/core/priv/priv/csr/SSTATUS_REGW
add wave -noupdate -group CSRs /testbench/dut/core/priv/priv/csr/STVEC_REGW
add wave -noupdate -group CSRs /testbench/dut/core/priv/priv/csr/SENVCFG_REGW
add wave -noupdate -group CSRs /testbench/dut/core/priv/priv/csr/csrs/csrs/STIMECMP_REGW
add wave -noupdate -group CSRs -group {user mode} /testbench/dut/core/priv/priv/csr/csru/csru/FRM_REGW
add wave -noupdate -group CSRs -group {user mode} /testbench/dut/core/priv/priv/csr/csru/csru/FFLAGS_REGW
add wave -noupdate -group CSRs -group {user mode} /testbench/dut/core/priv/priv/csr/csru/csru/STATUS_FS
add wave -noupdate -group CSRs -expand -group {Performance Counters} -label MCYCLE -radix unsigned {/testbench/dut/core/priv/priv/csr/counters/counters/HPMCOUNTER_REGW[0]}
add wave -noupdate -group CSRs -expand -group {Performance Counters} -label MINSTRET -radix unsigned {/testbench/dut/core/priv/priv/csr/counters/counters/HPMCOUNTER_REGW[2]}
add wave -noupdate -group CSRs -expand -group {Performance Counters} -expand -group BP -label Branch -radix unsigned {/testbench/dut/core/priv/priv/csr/counters/counters/HPMCOUNTER_REGW[3]}
add wave -noupdate -group CSRs -expand -group {Performance Counters} -expand -group BP -label {BP Dir Wrong} -radix unsigned {/testbench/dut/core/priv/priv/csr/counters/counters/HPMCOUNTER_REGW[7]}
add wave -noupdate -group CSRs -expand -group {Performance Counters} -expand -group BP -label {Jump (Not Return)} -radix unsigned {/testbench/dut/core/priv/priv/csr/counters/counters/HPMCOUNTER_REGW[4]}
add wave -noupdate -group CSRs -expand -group {Performance Counters} -expand -group BP -label Return -radix unsigned {/testbench/dut/core/priv/priv/csr/counters/counters/HPMCOUNTER_REGW[5]}
add wave -noupdate -group CSRs -expand -group {Performance Counters} -expand -group BP -label {BP Wrong} -radix unsigned {/testbench/dut/core/priv/priv/csr/counters/counters/HPMCOUNTER_REGW[6]}
add wave -noupdate -group CSRs -expand -group {Performance Counters} -expand -group BP -label {BTA Wrong} -radix unsigned {/testbench/dut/core/priv/priv/csr/counters/counters/HPMCOUNTER_REGW[8]}
add wave -noupdate -group CSRs -expand -group {Performance Counters} -expand -group BP -label {RAS Wrong} -radix unsigned {/testbench/dut/core/priv/priv/csr/counters/counters/HPMCOUNTER_REGW[9]}
add wave -noupdate -group CSRs -expand -group {Performance Counters} -expand -group BP -label {BP CLASS WRONG} -radix unsigned {/testbench/dut/core/priv/priv/csr/counters/counters/HPMCOUNTER_REGW[10]}
add wave -noupdate -group CSRs -expand -group {Performance Counters} -group ICACHE -label {I Cache Access} -radix unsigned {/testbench/dut/core/priv/priv/csr/counters/counters/HPMCOUNTER_REGW[16]}
add wave -noupdate -group CSRs -expand -group {Performance Counters} -group ICACHE -label {I Cache Miss} -radix unsigned {/testbench/dut/core/priv/priv/csr/counters/counters/HPMCOUNTER_REGW[17]}
add wave -noupdate -group CSRs -expand -group {Performance Counters} -group ICACHE -label {I Cache Miss Cycles} -radix unsigned {/testbench/dut/core/priv/priv/csr/counters/counters/HPMCOUNTER_REGW[18]}
add wave -noupdate -group CSRs -expand -group {Performance Counters} -group DCACHE -label {Load Stall} -radix unsigned {/testbench/dut/core/priv/priv/csr/counters/counters/HPMCOUNTER_REGW[11]}
add wave -noupdate -group CSRs -expand -group {Performance Counters} -group DCACHE -label {Store Stall} -radix unsigned {/testbench/dut/core/priv/priv/csr/counters/counters/HPMCOUNTER_REGW[12]}
add wave -noupdate -group CSRs -expand -group {Performance Counters} -group DCACHE -label {DCACHE MISS} -radix unsigned {/testbench/dut/core/priv/priv/csr/counters/counters/HPMCOUNTER_REGW[14]}
add wave -noupdate -group CSRs -expand -group {Performance Counters} -group DCACHE -label {DCACHE ACCESS} -radix unsigned {/testbench/dut/core/priv/priv/csr/counters/counters/HPMCOUNTER_REGW[13]}
add wave -noupdate -group CSRs -expand -group {Performance Counters} -group DCACHE -label {D Cache Miss Cycles} -radix unsigned {/testbench/dut/core/priv/priv/csr/counters/counters/HPMCOUNTER_REGW[15]}
add wave -noupdate -group CSRs -expand -group {Performance Counters} -group Privileged -label {CSR Write} {/testbench/dut/core/priv/priv/csr/counters/counters/HPMCOUNTER_REGW[19]}
add wave -noupdate -group CSRs -expand -group {Performance Counters} -group Privileged -label Fence.I {/testbench/dut/core/priv/priv/csr/counters/counters/HPMCOUNTER_REGW[20]}
add wave -noupdate -group CSRs -expand -group {Performance Counters} -group Privileged -label sfence.VMA {/testbench/dut/core/priv/priv/csr/counters/counters/HPMCOUNTER_REGW[21]}
add wave -noupdate -group CSRs -expand -group {Performance Counters} -group Privileged -label Interrupt {/testbench/dut/core/priv/priv/csr/counters/counters/HPMCOUNTER_REGW[22]}
add wave -noupdate -group CSRs -expand -group {Performance Counters} -group Privileged -label Exception {/testbench/dut/core/priv/priv/csr/counters/counters/HPMCOUNTER_REGW[23]}
add wave -noupdate -group CSRs -expand -group {Performance Counters} -label {FDiv or IDiv Cycles} {/testbench/dut/core/priv/priv/csr/counters/counters/HPMCOUNTER_REGW[24]}
add wave -noupdate -group CSRs -expand -group {Performance Counters} /testbench/dut/core/priv/priv/csr/counters/counters/HPMCOUNTER_REGW
add wave -noupdate -group alu /testbench/dut/core/ieu/dp/alu/A
add wave -noupdate -group alu /testbench/dut/core/ieu/dp/alu/B
add wave -noupdate -group alu /testbench/dut/core/ieu/dp/alu/ALUResult
add wave -noupdate -group alu /testbench/dut/core/ieu/dp/alu/BALUControl
add wave -noupdate -group alu -divider internals
add wave -noupdate -group Forward /testbench/dut/core/ieu/c/Rs1D
add wave -noupdate -group Forward /testbench/dut/core/ieu/c/Rs2D
add wave -noupdate -group Forward /testbench/dut/core/ieu/c/Rs1E
add wave -noupdate -group Forward /testbench/dut/core/ieu/c/Rs2E
add wave -noupdate -group Forward /testbench/dut/core/ieu/c/RdE
add wave -noupdate -group Forward /testbench/dut/core/ieu/c/RdM
add wave -noupdate -group Forward /testbench/dut/core/ieu/c/RdW
add wave -noupdate -group Forward /testbench/dut/core/ieu/c/MemReadE
add wave -noupdate -group Forward /testbench/dut/core/ieu/c/RegWriteM
add wave -noupdate -group Forward /testbench/dut/core/ieu/c/RegWriteW
add wave -noupdate -group Forward -color Thistle /testbench/dut/core/ieu/c/ForwardAE
add wave -noupdate -group Forward -color Thistle /testbench/dut/core/ieu/c/ForwardBE
add wave -noupdate -group Forward -color Thistle /testbench/dut/core/ieu/c/LoadStallD
add wave -noupdate -group Forward /testbench/dut/core/ieu/dp/IFResultM
add wave -noupdate -group Forward /testbench/dut/core/ieu/c/ForwardAE
add wave -noupdate -group Forward /testbench/dut/core/ieu/c/Rs1E
add wave -noupdate -group Forward /testbench/dut/core/ieu/c/RdM
add wave -noupdate -group Forward /testbench/dut/core/ieu/c/RdW
add wave -noupdate -group {alu execution stage} /testbench/dut/core/ieu/dp/ALUResultE
add wave -noupdate -group {alu execution stage} /testbench/dut/core/ieu/dp/SrcAE
add wave -noupdate -group {alu execution stage} /testbench/dut/core/ieu/dp/SrcBE
add wave -noupdate -group FPU /testbench/dut/core/fpu/fpu/FRD1E
add wave -noupdate -group FPU /testbench/dut/core/fpu/fpu/FRD2E
add wave -noupdate -group FPU /testbench/dut/core/fpu/fpu/FRD3E
add wave -noupdate -group FPU /testbench/dut/core/fpu/fpu/ForwardedSrcAE
add wave -noupdate -group FPU /testbench/dut/core/fpu/fpu/ForwardedSrcBE
add wave -noupdate -group FPU /testbench/dut/core/fpu/fpu/Funct3E
add wave -noupdate -group FPU /testbench/dut/core/fpu/fpu/W64E
add wave -noupdate -group FPU /testbench/dut/core/fpu/fpu/unpack/X
add wave -noupdate -group FPU /testbench/dut/core/fpu/fpu/unpack/Y
add wave -noupdate -group FPU /testbench/dut/core/fpu/fpu/unpack/Z
add wave -noupdate -group FPU /testbench/dut/core/fpu/fpu/fregfile/rf
add wave -noupdate -group wfi /testbench/dut/core/priv/priv/pmd/STATUS_TW
add wave -noupdate -group wfi /testbench/dut/core/priv/priv/pmd/PrivilegeModeW
add wave -noupdate -group wfi /testbench/dut/core/priv/priv/pmd/wfi/WFICount
add wave -noupdate -group wfi /testbench/dut/core/priv/priv/pmd/WFITimeoutM
add wave -noupdate -group testbench /testbench/DCacheFlushStart
add wave -noupdate /testbench/dut/core/lsu/hptw/hptw/HPTWLoadPageFault
add wave -noupdate /testbench/dut/core/lsu/hptw/hptw/HPTWLoadPageFaultDelay
add wave -noupdate -group spi /testbench/dut/uncoregen/uncore/spi/spi/PCLK
add wave -noupdate -group spi -expand -group interface /testbench/dut/uncoregen/uncore/spi/spi/SPICLK
add wave -noupdate -group spi -expand -group interface /testbench/dut/uncoregen/uncore/spi/spi/SPICS
add wave -noupdate -group spi -expand -group interface /testbench/dut/uncoregen/uncore/spi/spi/SPIOut
add wave -noupdate -group spi -expand -group interface /testbench/dut/uncoregen/uncore/spi/spi/SPIIn
add wave -noupdate -group spi /testbench/dut/uncoregen/uncore/spi/spi/ChipSelectMode
add wave -noupdate -group spi /testbench/dut/uncoregen/uncore/spi/spi/SckMode
add wave -noupdate /testbench/dut/uncoregen/uncore/spi/spi/ShiftEdge
add wave -noupdate /testbench/dut/uncoregen/uncore/spi/spi/TransmitData
add wave -noupdate /testbench/dut/core/ifu/bus/icache/icache/cachefsm/CacheEn
add wave -noupdate /testbench/dut/core/ifu/bus/icache/icache/cachefsm/FlushStage
add wave -noupdate /testbench/dut/core/lsu/bus/dcache/dcache/vict/cacheLRU/LRUWriteEn
add wave -noupdate /testbench/dut/core/lsu/bus/dcache/dcache/vict/cacheLRU/FlushStage
add wave -noupdate -group Debug -expand -group jtag /testbench/dut/debug/dtm/tck
add wave -noupdate -group Debug -expand -group jtag /testbench/dut/debug/dtm/tms
add wave -noupdate -group Debug -expand -group jtag /testbench/dut/debug/dtm/tdi
add wave -noupdate -group Debug -expand -group jtag /testbench/dut/debug/dtm/tdo
add wave -noupdate -group Debug -expand -group dtm /testbench/dut/debug/dtm/DMIADDR
add wave -noupdate -group Debug -expand -group dtm /testbench/dut/debug/dtm/DMIDATA
add wave -noupdate -group Debug -expand -group dtm /testbench/dut/debug/dtm/DMIOP
add wave -noupdate -group Debug -expand -group dtm /testbench/dut/debug/dtm/DMIREADY
add wave -noupdate -group Debug -expand -group dtm /testbench/dut/debug/dtm/DMIVALID
add wave -noupdate -group Debug -expand -group dtm -group {registers} /testbench/dut/debug/dtm/currentInst
add wave -noupdate -group Debug -expand -group dtm -group {registers} /testbench/dut/debug/dtm/dmi
add wave -noupdate -group Debug -expand -group dtm -group {registers} /testbench/dut/debug/dtm/dtmcs
add wave -noupdate -group Debug -expand -group dm /testbench/dut/debug/debug/DMIRSPDATA
add wave -noupdate -group Debug -expand -group dm /testbench/dut/debug/debug/DMIRSPOP
add wave -noupdate -group Debug -expand -group dm /testbench/dut/debug/debug/DMIRSPREADY
add wave -noupdate -group Debug -expand -group dm /testbench/dut/debug/debug/DMIRSPVALID
add wave -noupdate -group Debug -expand -group dm /testbench/dut/debug/debug/DebugNDMReset
add wave -noupdate -group Debug -expand -group dm /testbench/dut/debug/debug/AnyResumeAck
add wave -noupdate -group Debug -expand -group dm -group {Debug Registers} /testbench/dut/debug/debug/DMControl
add wave -noupdate -group Debug -expand -group dm -group {Debug Registers} /testbench/dut/debug/debug/DMStatus
add wave -noupdate -group Debug -expand -group dm -group {Debug Registers} /testbench/dut/debug/debug/Data0
add wave -noupdate -group Debug -expand -group dm -group {Debug Registers} /testbench/dut/debug/debug/Data1
add wave -noupdate -group Debug -expand -group dm -group {Debug Registers} /testbench/dut/debug/debug/AbstractCS
add wave -noupdate -group Debug -expand -group dm -group {Debug Registers} /testbench/dut/debug/debug/Command
add wave -noupdate -group Debug -expand -group csrd /testbench/dut/core/priv/priv/csr/debug/csrd/DebugMode
add wave -noupdate -group Debug -expand -group csrd /testbench/dut/core/priv/priv/csr/debug/csrd/cause
add wave -noupdate -group Debug -expand -group csrd /testbench/dut/core/priv/priv/csr/debug/csrd/DebugHaltReq
add wave -noupdate -group Debug -expand -group csrd /testbench/dut/core/priv/priv/csr/debug/csrd/DebugResumeReq
add wave -noupdate -group Debug -expand -group csrd /testbench/dut/core/priv/priv/csr/debug/csrd/DebugResetHaltReq
add wave -noupdate -group Debug -expand -group csrd /testbench/dut/core/priv/priv/csr/debug/csrd/DPC_REGW
add wave -noupdate -group Debug -expand -group csrd /testbench/dut/core/priv/priv/csr/debug/csrd/DPCWriteValM
add wave -noupdate -group Debug -expand -group csrd /testbench/dut/core/priv/priv/csr/debug/csrd/DCSR_REGW
add wave -noupdate -group Debug -expand -group csrd /testbench/dut/core/priv/priv/csr/debug/csrd/DCSRWriteValM
add wave -noupdate -group Debug -expand -group csrd /testbench/dut/core/priv/priv/csr/debug/csrd/WriteDCSR
add wave -noupdate -group Debug -expand -group csrd /testbench/dut/core/priv/priv/csr/debug/csrd/WriteDPC
add wave -noupdate -group Debug -expand -group csrd /testbench/dut/core/priv/priv/csr/debug/csrd/InstrValidE
add wave -noupdate -group Debug -expand -group csrd /testbench/dut/core/priv/priv/csr/debug/csrd/DPCset
add wave -noupdate -group Debug -expand -group csrd /testbench/dut/core/priv/priv/csr/debug/csrd/DebugResume
add wave -noupdate -group Debug -expand -group csrd /testbench/dut/core/priv/priv/csr/debug/csrd/ebreak
add wave -noupdate -group Debug -expand -group csrd /testbench/dut/core/priv/priv/csr/debug/csrd/ebreakm
add wave -noupdate -group Debug -expand -group csrd /testbench/dut/core/priv/priv/csr/debug/csrd/ebreaks
add wave -noupdate -group Debug -expand -group csrd /testbench/dut/core/priv/priv/csr/debug/csrd/ebreaku
add wave -noupdate -group Debug -expand -group csrd /testbench/dut/core/priv/priv/csr/debug/csrd/step
add wave -noupdate -group Debug -expand -group csrd /testbench/dut/core/priv/priv/csr/debug/csrd/Stepping
add wave -noupdate -group Debug -expand -group csrd /testbench/dut/core/priv/priv/csr/debug/csrd/state
add wave -noupdate -group Debug -expand -group csrd /testbench/dut/core/priv/priv/csr/debug/csrd/state_n
add wave -noupdate -group Debug -expand -group csrd /testbench/dut/core/priv/priv/csr/debug/csrd/NextHalt
add wave -noupdate -group Debug -expand -group csrd /testbench/dut/core/priv/priv/csr/debug.csrd/DebugHaveReset
add wave -noupdate -group Debug -expand -group csrd /testbench/dut/core/priv/priv/csr/debug.csrd/DebugHaveResetAck
add wave -noupdate -group Debug -expand -group csrd -group {DPC Sources} /testbench/dut/core/priv/priv/csr/debug/csrd/PCSrcM
add wave -noupdate -group Debug -expand -group csrd -group {DPC Sources} /testbench/dut/core/priv/priv/csr/debug/csrd/IEUAdrM
add wave -noupdate -group Debug -expand -group csrd -group {DPC Sources} /testbench/dut/core/priv/priv/csr/debug/csrd/PCM
add wave -noupdate -group Debug -expand -group csrd -group {DPC Sources} /testbench/dut/core/priv/priv/csr/debug/csrd/NextValidPCE
add wave -noupdate -group Debug -expand -group abstract /testbench/dut/debug/debug/StartCommand
add wave -noupdate -group Debug -expand -group abstract /testbench/dut/debug/debug/ValidCommand
add wave -noupdate -group Debug -expand -group abstract /testbench/dut/debug/debug/ValidSize
add wave -noupdate -group Debug -expand -group abstract /testbench/dut/debug/debug/AARSize
add wave -noupdate -group Debug -expand -group abstract /testbench/dut/debug/debug/DebugGPREnable
add wave -noupdate -group Debug -expand -group abstract /testbench/dut/debug/debug/DebugCSREnable
add wave -noupdate -group Debug -expand -group abstract /testbench/dut/debug/debug/DebugFPREnable
add wave -noupdate -group Debug -expand -group abstract /testbench/dut/debug/debug/DebugRegRDATA
add wave -noupdate -group Debug -expand -group abstract /testbench/dut/debug/debug/DebugRegWDATA
add wave -noupdate -group Debug -expand -group abstract /testbench/dut/debug/debug/DebugRegAddr
add wave -noupdate -group Debug -expand -group abstract /testbench/dut/debug/debug/DebugRegWrite



TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 4} {89834 ns} 1} {{Cursor 4} {79055 ns} 1} {{Cursor 3} {89604 ns} 0}
quietly wave cursor active 3
configure wave -namecolwidth 250
configure wave -valuecolwidth 194
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {89564 ns} {89776 ns}
