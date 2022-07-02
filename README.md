# EU_Gas_Model
Development Repo for EU Gas Model out of ZERO Lab.

The purpose of this model is to provide a test-bed for various policy environments as a resource to EU energy security, as well as to highlight bottlenecks in the current system. This ReadMe includes basic installation and operation instructions, along with a brief description of the model and its input files for full transparency. 

# Installation and Branch Description
Instructions for model operation are as follows:
  1. Clone the repository to your local machine. The key active branches are New2025, which models the European gas system from April 2025 - March 2026 and countryspecdem, which models the European gas system from April 2022 - March 2024. Both exclude Hungary and Slovakia from consideration due to their objections over the EU oil embargo.
  2. The core runfile for each model is GasModelV2.jl. This file contains several paths which must be updated to reflect locations and limitations of your local machine. Access to a solver is required. As this is a linear program, any LP solver should work, though solve times will depend on solver and hardware. The solver can be selected at line 682.
  3. The model should be ready to run, and may be run assuming that all required packages have been installed in your local julia instance. 
  
  Settings can be found in the main() function and in the ReducSelector.csv and RussiaReduc.csv sheets. Within main(), the following settings should not be touched - imports_vol = true, no_turkst = true. These ensure that the correct imports data are read into the program. The rus_cut setting is an artefact and thus does not impact the program. The other settings are malleable. EU_stor can be set to true if the modeler wants to require gas storage to reach 90% capacity by October 1 each year, as required by the European Commission, while EU_stor = false allows a scaled constraint, which is discussed below. no_reduc controls CHP demand reductions, it should only be true in cases where no CHP demand reduction is desired. The RussiaReduc.csv sheet allows each country's maximum consumption of Russian gas to be constrained as a proportion of its import pipeline capacity. Each column is one month and each row is a country, corresponding to the canonical country list order in countrylist.csv. Similarly, each row in ReducSelector.csv corresponds to a country, with demand reductions in gas use selectable on a per country basis. Each reduction is scaled in from April to October reaching a reduction of the proportion listed at the right hand side. Each number input corresponds with a different level of demand reduction.
  
# Input Data File Descriptions and Data Sources
## Post-Files
  All folders labeled Post contained within the Inputs directory are sets of compiled results of model runs of an instance of PyPSA, an open source European Electricity System modeling effort found at https://github.com/PyPSA/PyPSA. For familiarity and ease of use, input files from PyPSA were transformed and imported to a local version of GenX, another open source electricity system model found at https://github.com/GenXProject/GenX. Each folder contains a range of assessed scenarios, differentiated by their level of assumed electricity demand reduction and fuel switching from gas to coal. The data contained within is formatted as the proportion of expected gas demand for electricity actually required by the electricity sector model in a particular month in a particular country. Within the main code, the post-file is specifiable by the user. The most current input files are Post New and Post Accel.
  
## Demand, Biogas, and Production Files
  With the current settings, the model uses Demand2223NoObj.csv and Production2223NoObj.csv as its core demand and production settings. These contain wrapped versions of the 2021 monthly gas demand and production data from Eurostat in mcm/month, with data gaps filled in by previous years for certain countries as needed (Eurostat, 2022a). The Biogas.csv file contains each country's monthly average production of renewable biomethane in 2021, as provided by Eurostat (2022b). Biogas production is assumed to be identical between months.

## Import Constraint Files
  Two levels of import constraints are currently included in the input files. ImportCaps.csv represents the theoretical annual import capacities of each country from 7 import sources: Algeria, LNG markets, Libya, Norway, Turkey and Azerbaijan, Russia, and the Baltic. ImportVols.csv further constrains the usable import capacity of pipelines to be their average flow over the winter months from 2021-2022, benchmarked by data from ENTSO-G's transparency dashboard, found at https://transparency.entsog.eu/#/map. LNG import capacities are taken from the LNG database from GIE, found at https://www.gie.eu/transparency/databases/lng-database/, supplemented by various FRSU leasing announcements, particularly for Finland and Germany. All units are in mcm/day. We excluded the currently closed Medgaz pipeline between Spain and Algeria.
  
## 
$$
M = \sum^a_b{x^2 + y^n}
$$

# Model Structure Description
  This is a linear programming model designed to represent all key technical constraints of the European gas network at country-level spatial resolution and monthly temporal resolution. The current model setup includes 28 countries over the course of 24 months, the full list of which is included in CountryList.csv. Due to the Ukrainian ban on gas exports and significant uncertainty in Ukrainian gas demand, we specifically exclude Ukrainian gas storage, demand, production, and transmission from consideration (Stuart, 2022). Additionally, due to their objections to the EU oil embargo, we similarly exclude Hungarian and Slovakian storage, demand, and production while allowing the continued use of Hungarian and Slovakian gas transmission by the rest of the European system. It is assumed that Hungary and Slovakia can source all their domestic gas demands through continued imports from Russia.
  
