# 🚀 AXI4 Memory-Mapped Slave Verification (SystemVerilog)



## 📌 Overview



This project presents a **complete verification environment** for an **AXI4 Memory-Mapped Slave**, developed using **SystemVerilog (non-UVM methodology)**. It demonstrates strong fundamentals in **digital IC verification**, including constrained-random stimulus generation, protocol checking, functional coverage, and a self-checking testbench architecture.



The design under test (DUT) is an AXI4-compliant slave connected to an internal synchronous memory, supporting **burst read and write transactions**.



---



## 🎯 Objectives



* Verify correctness of AXI4 protocol behavior

* Validate read/write transactions with burst support

* Detect protocol violations using assertions

* Achieve high functional coverage

* Build a scalable, modular verification environment



---



## 🧠 Key Features



### ✅ AXI4 Protocol Support



* Write Address Channel (AW)

* Write Data Channel (W)

* Write Response Channel (B)

* Read Address Channel (AR)

* Read Data Channel (R)



### ✅ Constrained Random Verification



* Randomized:



* Address (aligned \& corner cases)

* Burst length (LEN)

* Transfer size (SIZE)

* Operation type (Read / Write)

* Data patterns

* Handshake delays (VALID/READY timing)



### ✅ Functional Coverage



* Coverage groups for:



* Address space

* Data patterns

* Burst lengths

* Operation types

* Ensures verification completeness



### ✅ Self-Checking Testbench



* Golden reference model

* Automatic comparison:



* Expected vs Actual data

* Expected vs Actual response

* Pass/Fail tracking



### ✅ SystemVerilog Assertions (SVA)



* Protocol correctness checks:



* Handshake validity

* Signal stability

* Response correctness

* Address boundary validation



### ✅ Modular Testbench Architecture



* Interface-based communication

* Driver / Monitor / Scoreboard separation

* Reusable and scalable structure



---



## 📂 Project Structure



```

axi4\_memory\_mapped\_slave\_verification/

├── rtl/

│   ├── axi4.sv

│   └── axi4\_memory.sv

│

├── tb/

│   ├── axi4\_interface.sv

│   ├── axi4\_transaction.sv

│   ├── axi4\_driver.sv

│   ├── axi4\_monitor.sv

│   ├── axi4\_scoreboard.sv

│   ├── axi4\_sequencer.sv

│   ├── axi4\_assert.sv

│   └── axi4\_testbench.sv

│

├── memory\_standalone\_test/

│   ├── rtl/

│   │   └── axi4\_memory.sv

│   ├── tb/

│   │   ├── memory\_interface.sv

│   │   ├── memory\_class.sv

│   │   ├── mem\_test.sv

│   │   └── mem\_assert.sv

│

├── sim/

│   └── run\_sim.sh

│

└── README.md

```



---



## ⚙️ How to Run Simulation



### 1. Navigate to simulation directory



```bash

cd sim

```



### 2. Run simulation script



```bash

chmod +x run\_sim.sh

./run\_sim.sh

```



> 💡 You can modify the script to support your simulator (Questa, VCS, Xcelium)



---



## 📊 Verification Flow



1\. Generate randomized transaction

2\. Drive signals through AXI interface

3\. Monitor DUT behavior

4\. Compare with golden model

5\. Check assertions

6\. Update coverage

7\. Log results



---



## 📈 Results



* ✔️ High functional coverage achieved

* ✔️ Robust handling of corner cases

* ✔️ Automatic pass/fail reporting

* ✔️ Protocol compliance verified using assertions



---



## 💡 What This Project Demonstrates



* Strong understanding of **AXI4 protocol**

* Ability to build **verification environments from scratch**

* Practical use of:



* Constrained randomization

* Functional coverage

* Assertions (SVA)

* Clean, modular, **industry-style testbench design**


---



## 🔮 Future Improvements



* Migrate to **UVM-based environment**

* Add:



* AXI4-Lite support

* Out-of-order transactions

* Backpressure stress testing

* Integrate with CI (GitHub Actions)



---



## 👨‍💻 Author



**Kareem Elhafi**

Digital IC Design \& Verification Enthusiast



--

