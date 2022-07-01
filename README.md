# EU_Gas_Model
Development Repo for EU Gas Model out of ZERO Lab.

The purpose of this model is to provide a test-bed for various policy environments as a resource to EU energy security, as well as to highlight bottlenecks in the current system. This ReadMe includes basic installation and operation instructions, along with a brief description of the model and its input files for full transparency.

# Installation and Branch Description
Instructions for model operation are as follows:
  1. Clone the repository to your local machine. The key active branches are New2025, which models the European gas system from April 2025 - March 2026 and countryspecdem, which models the European gas system from April 2022 - March 2024. Both exclude Hungary and Slovakia from consideration due to their objections over the EU oil embargo.
  2. The core runfile for each model is GasModelV2.jl. This file contains several paths which must be updated to reflect locations and limitations of your local machine. Access to a solver is required. As this is a linear program, any LP solver should work, though solve times will depend on solver and hardware. The solver can be selected at line 682.
  3. The model should be ready to run, and may be run assuming that all required packages have been installed in your local julia instance. 
  
  Settings can be found in the main() function and in the ReducSelector.csv and RussiaReduc.csv sheets. Within main(), the following settings should not be touched - imports_vol = true, no_turkst = true. These ensure that the correct imports data are read into the program. The rus_cut setting is an artefact and thus does not impact the program. The other settings are malleable. EU_stor can be set to true if the modeler wants to require gas storage to reach 90% capacity by October 1 each year, as required by the European Commission, while EU_stor = false allows a scaled constraint, which is discussed below. no_reduc controls CHP demand reductions, it should only be true in cases where no CHP demand reduction is desired. The RussiaReduc.csv sheet allows each country's maximum consumption of Russian gas to be constrained as a proportion of its import pipeline capacity. Each column is one month and each row is a country, corresponding to the canonical country list order in countrylist.csv. Similarly, each row in ReducSelector.csv corresponds to a country, with demand reductions in gas use selectable on a per country basis. Each reduction is scaled in from April to October reaching a reduction of the proportion listed at the the right hand side. Each number input corresponds with a different level of demand reduction.
  
# Model Description

# Input Data File Descriptions and Sources
