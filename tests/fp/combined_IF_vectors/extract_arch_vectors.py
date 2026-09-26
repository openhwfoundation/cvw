#!/usr/bin/env -S uv run --script

# author: Alessandro Maiuolo, Kevin Kim
# contact: amaiuolo@g.hmc.edu, kekim@hmc.edu
# date created: 3-29-2023

# extract all arch test vectors
import os

wally = os.popen('echo $WALLY').read().strip()

def ext_bits(my_string):
    target_len = 32 # we want 128 bits, div by 4 bc hex notation
    zeroes_to_add = target_len - len(my_string)
    return zeroes_to_add*"0" + my_string

def twos_comp(b, x):
    if b == 32:
        return hex(0x100000000 - int(x,16))[2:]
    elif b == 64:
        return hex(0x10000000000000000 - int(x,16))[2:]
    else:
        return "UNEXPECTED_BITSIZE"

def unpack_rf(packed):
    bin_u = bin(int(packed, 16))[2:].zfill(8) # translate to binary
    flags = hex(int(bin_u[3:],2))[2:].zfill(2)
    rounding_mode = hex(int(bin_u[:3],2))[2:]
    return flags, rounding_mode

# rounding mode dictionary
round_dict = {
    "rne":"0",
    "rnm":"4",
    "ru":"3",
    "rz":"1",
    "rd":"2",
    "dyn":"7"
}

# fcsr dictionary
fcsr_dict = {
    "0":"rne",
    "128":"rnm",
    "96":"ru",
    "32":"rz",
    "64":"rd",
    "224":"dyn"
}

print("creating arch test vectors")

class Config:
  def __init__(self, bits, letter, op, filt, op_code):
    self.bits = bits
    self.letter = letter
    self.op = op
    self.filt = filt
    self.op_code = op_code

def create_vectors(my_config):
    suite_folder_num = my_config.bits
    if my_config.bits == 64 and my_config.letter == "F": suite_folder_num = 32
    source_dir1 = f"{wally}/addins/riscv-arch-test/riscv-test-suite/rv{suite_folder_num}i_m/{my_config.letter}/src/"
    source_dir2 = f"{wally}/tests/riscof/work/riscv-arch-test/rv{my_config.bits}i_m/{my_config.letter}/src/"
    dest_dir = f"{wally}/tests/fp/combined_IF_vectors/IF_vectors/"
    all_vectors1 = os.listdir(source_dir1)

    filt_vectors1 = [v for v in all_vectors1 if my_config.filt in v]
    # print(filt_vectors1)
    filt_vectors2 = [v + "/ref/Reference-sail_c_simulator.signature" for v in all_vectors1 if my_config.filt in v]

    # iterate through all vectors
    for i in range(len(filt_vectors1)):
        vector1 = filt_vectors1[i]
        vector2 = filt_vectors2[i]
        operation = my_config.op_code
        rounding_mode = "X"
        flags = "XX"
        # use name to create our new tv and open vectors
        with open(f"{dest_dir}cvw_{my_config.bits}_{vector1[:-2]}.tv", 'w') as dest_file, open(source_dir1 + vector1) as src_file1, open(source_dir2 + vector2) as src_file2:
            # for each test in the vector
            reading = True
            src_file2.readline() #skip first bc junk
            # print(my_config.bits, my_config.letter)
            if my_config.letter == "F" and my_config.bits == 64:
                reading = True
                # print("trigger 64F")
                #skip first 2 lines bc junk
                src_file2.readline()
                while reading:
                    # get answer and flags from Ref...signature
                    # answers are before deadbeef (first line of 4)
                    # flags are after deadbeef (third line of 4)
                    answer = src_file2.readline().strip()
                    deadbeef = src_file2.readline().strip()
                    # print(answer)
                    if not (answer == "e7d4b281" and deadbeef == "6f5ca309"): # if there is still stuff to read
                        # get flags
                        packed = src_file2.readline().strip()[6:]
                        flags, rounding_mode = unpack_rf(packed)
                        # skip 00000000 buffer
                        src_file2.readline()

                        # parse through .S file
                        detected = False
                        done = False
                        op1val = "0"
                        op2val = "0"
                        while not (detected or done):
                            # print("det1")
                            line = src_file1.readline()
                            # print(line)
                            if "op1val" in line:
                                # print("det2")
                                # parse line

                                # handle special case where destination register is hardwired to zero
                                if "dest:x0" in line:
                                    answer = "x" * len(answer)

                                op1val = line.split("op1val")[1].split("x")[1].split(";")[0]
                                if my_config.op != "fsqrt": # sqrt doesn't have two input vals
                                    op2val = line.split("op2val")[1].split("x")[1].strip()
                                    if op2val[-1] == ";": op2val = op2val[:-1] # remove ; if it's there
                                else:
                                    op2val = 32*"X"
                                # go to next test in vector
                                detected = True
                            elif "RVTEST_CODE_END" in line:
                                done = True
                        # put it all together
                        if not done:
                            translation = f"{operation}_{ext_bits(op1val)}_{ext_bits(op2val)}_{ext_bits(answer.strip())}_{flags}_{rounding_mode}"
                            dest_file.write(translation + "\n")
                    else:
                        # print("read false")
                        reading = False
            elif my_config.letter == "M" and my_config.bits == 64:
                reading = True
                #skip first 2 lines bc junk
                src_file2.readline()
                while reading:
                    # print("trigger 64M")
                    # get answer from Ref...signature
                    # answers span two lines and are reversed
                    answer2 = src_file2.readline().strip()
                    answer1 = src_file2.readline().strip()
                    answer = answer1 + answer2
                    #print(answer1,answer2)
                    if not (answer2 == "e7d4b281" and answer1 == "6f5ca309"): # if there is still stuff to read
                        # parse through .S file
                        detected = False
                        done = False
                        op1val = "0"
                        op2val = "0"
                        while not (detected or done):
                            # print("det1")
                            line = src_file1.readline()
                            # print(line)
                            if "op1val" in line:
                                # print("det2")
                                # parse line
                                # handle special case where destination register is hardwired to zero
                                if "dest:x0" in line:
                                    answer = "x" * len(answer)
                                op1val = line.split("op1val")[1].split("x")[1].split(";")[0]
                                if "-" in line.split("op1val")[1].split("x")[0]: # neg sign handling
                                    op1val = twos_comp(my_config.bits, op1val)
                                if my_config.op != "fsqrt": # sqrt doesn't have two input vals, unnec here but keeping for later
                                    op2val = line.split("op2val")[1].split("x")[1].strip()
                                    if op2val[-1] == ";": op2val = op2val[:-1] # remove ; if it's there
                                    if "-" in line.split("op2val")[1].split("x")[0]: # neg sign handling
                                        op2val = twos_comp(my_config.bits, op2val)
                                # go to next test in vector
                                detected = True
                            elif "RVTEST_CODE_END" in line:
                                done = True
                        # ints don't have flags
                        flags = "XX"
                        # put it all together
                        if not done:
                            translation = f"{operation}_{ext_bits(op1val)}_{ext_bits(op2val)}_{ext_bits(answer.strip())}_{flags.strip()}_{rounding_mode}"
                            dest_file.write(translation + "\n")
                    else:
                        # print("read false")
                        reading = False
            elif my_config.letter == "M" and my_config.bits == 32:
                reading = True
                while reading:
                    # print("trigger 64M")
                    # get answer from Ref...signature
                    # answers span two lines and are reversed
                    answer = src_file2.readline().strip()
                    # print(f"Answer: {answer}")
                    #print(answer1,answer2)
                    if answer != '6f5ca309': # if there is still stuff to read
                        # parse through .S file
                        detected = False
                        done = False
                        op1val = "0"
                        op2val = "0"
                        while not (detected or done):
                            # print("det1")
                            line = src_file1.readline()
                            # print(line)
                            if "op1val" in line:
                                # print("det2")
                                # parse line
                                # handle special case where destination register is hardwired to zero
                                if "dest:x0" in line:
                                    answer = "x" * len(answer)
                                op1val = line.split("op1val")[1].split("x")[1].split(";")[0]
                                if "-" in line.split("op1val")[1].split("x")[0]: # neg sign handling
                                    op1val = line.split("op1val")[1].split("x")[1].split(";")[0]
                                if "-" in line.split("op1val")[1].split("x")[0]: # neg sign handling
                                    op1val = twos_comp(my_config.bits, op1val)
                                if my_config.op != "fsqrt": # sqrt doesn't have two input vals, unnec here but keeping for later
                                    op2val = line.split("op2val")[1].split("x")[1].strip()
                                    if op2val[-1] == ";": op2val = op2val[:-1] # remove ; if it's there
                                    if "-" in line.split("op2val")[1].split("x")[0]: # neg sign handling
                                        op2val = twos_comp(my_config.bits, op2val)
                                # go to next test in vector
                                detected = True
                            elif "RVTEST_CODE_END" in line:
                                done = True
                        # ints don't have flags
                        flags = "XX"
                        # put it all together
                        if not done:
                            translation = f"{operation}_{ext_bits(op1val)}_{ext_bits(op2val)}_{ext_bits(answer.strip())}_{flags.strip()}_{rounding_mode}"
                            dest_file.write(translation + "\n")
                    else:
                        # print("read false")
                        reading = False
            else:
                while reading:
                    # get answer and flags from Ref...signature
                    answer = src_file2.readline()
                    #print(answer)
                    packed = src_file2.readline()[6:]
                    #print("Packed: ", packed)
                    if len(packed.strip())>0: # if there is still stuff to read
                        # print("packed")
                        # parse through .S file
                        detected = False
                        done = False
                        op1val = "0"
                        op2val = "0"
                        while not (detected or done):
                            # print("det1")
                            line = src_file1.readline()
                            # print(line)
                            if "op1val" in line:
                                # print("det2")
                                # parse line

                                # handle special case where destination register is hardwired to zero
                                if "dest:x0" in line:
                                    answer = "x" * len(answer)

                                op1val = line.split("op1val")[1].split("x")[1].split(";")[0]
                                if "-" in line.split("op1val")[1].split("x")[0]: # neg sign handling
                                    op1val = twos_comp(my_config.bits, op1val)
                                if my_config.op != "fsqrt": # sqrt doesn't have two input vals
                                    op2val = line.split("op2val")[1].split("x")[1].strip()
                                    if op2val[-1] == ";": op2val = op2val[:-1] # remove ; if it's there
                                    if "-" in line.split("op2val")[1].split("x")[0]: # neg sign handling
                                        op2val = twos_comp(my_config.bits, op2val)
                                # go to next test in vector
                                detected = True
                            elif "RVTEST_CODE_END" in line:
                                done = True
                        # rounding mode for float
                        if not done and (my_config.op == "fsqrt" or my_config.op == "fdiv"):
                            flags, rounding_mode = unpack_rf(packed)

                        # put it all together
                        if not done:
                            translation = f"{operation}_{ext_bits(op1val)}_{ext_bits(op2val)}_{ext_bits(answer.strip())}_{flags}_{rounding_mode}"
                            dest_file.write(translation + "\n")
                    else:
                        # print("read false")
                        reading = False
            # print("out")

config_list = [
Config(32, "M", "div", "div-", 0),
Config(32, "F", "fdiv", "fdiv", 1),
Config(32, "F", "fsqrt", "fsqrt", 2),
Config(32, "M", "rem", "rem-", 3),
Config(32, "M", "divu", "divu-", 4),
Config(32, "M", "remu", "remu-", 5),
Config(64, "M", "div", "div-", 0),
Config(64, "F", "fdiv", "fdiv", 1),
Config(64, "F", "fsqrt", "fsqrt", 2),
Config(64, "M", "rem", "rem-", 3),
Config(64, "M", "divu", "divu-", 4),
Config(64, "M", "remu", "remu-", 5),
Config(64, "M", "divw", "divw-", 6),
Config(64, "M", "divuw", "divuw-", 7),
Config(64, "M", "remw", "remw-", 8),
Config(64, "M", "remuw", "remuw-", 9)
]

for c in config_list:
    create_vectors(c)
