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
  With the current settings, the model uses Demand2223NoObj.csv and Production2223NoObj.csv as its baseline demand and production settings. These contain wrapped versions of the 2021 monthly gas demand and production data from Eurostat in mcm/month, with data gaps filled in by previous years for certain countries as needed (Eurostat, 2022a). The Biogas.csv file contains each country's monthly average production of renewable biomethane in 2021, as provided by Eurostat (2022b). Biogas production is assumed to be identical between months. All units are in mcm/month.
  SectorUse.csv is also important here, containing the sectoral breakdown of gas use on a country-by-country basis between Electricity, Industry, Combined Heat and Power, Commercial, and Residential uses. This data is taken from Eurostat's Energy Flows Database found at: https://ec.europa.eu/eurostat/databrowser/view/. 

## Import Constraint Files
  Two levels of import constraints are currently included in the input files. ImportCaps.csv represents the theoretical annual import capacities of each country from 7 import sources: Algeria, LNG markets, Libya, Norway, Turkey and Azerbaijan, Russia, and the Baltic. ImportVols.csv further constrains the usable import capacity of pipelines to be their average flow over the winter months from 2021-2022, benchmarked by data from ENTSO-G's transparency dashboard, found at https://transparency.entsog.eu/#/map. LNG import capacities are taken from the LNG database from GIE, found at https://www.gie.eu/transparency/databases/lng-database/, supplemented by various FRSU leasing announcements, particularly for Finland and Germany. All units are in mcm/day. Note, we excluded the currently closed Medgaz pipeline between Spain and Algeria and the backflow of gas from the Turkish gas grid to Bulgaria through the Strandzha 2/Malkoclar trading point. 
  
## Transmission and Storage Files
  All required data on transmission and storage within the modeled countries is included in the TransmissionCap.csv and StorageNoObj.csv folders. Transmission capacities are organized as a 28x28 matrix, with columns representing the country the pipeline leaves from and rows representing the country to which each pipeline delivers. For instance, a hypothetical pipeline from Bulgaria to Belgium would be represented in space {2,1} of the matrix. All transmission capacities are aggregated on a country-country level, meaning that the capacities of all pipelines from country A to country B are summed together within the same cell. The transmission capacity data contained within is sourced from GIE's system development map, found at https://www.entsog.eu/sites/default/files/2021-01/ENTSOG_GIE_SYSDEV_2019-2020_1600x1200_FULL_047.pdf, with corrections made based on capacities found in ENTSO-G's transparency dashboard where significant differences were found. All transmission flow capacity units are in mcm/day. The storage file contains storage quantities in mcm in each country expected to be finished by 2022, 2025, and 2030, projected based on planning/construction status as reported in GIE's storage database, found at https://www.gie.eu/transparency/databases/storage-database/.

## Emissions Accounting Input Files
  Emissions intensivity data is contained in EmissionsIntensity.csv and ProdEmissions.csv. Emissions intensities for different parts of the lifecycle were taken from the following documents: the NETL report for US LNG (Roman-White et al., 2019),  and an EU report on Life Cycle Emissions from Natural gas from various countries in transport setting found here https://ec.europa.eu/energy/sites/ener/files/documents/Study%20on%20Actual%20GHG%20Data%20Oil%20Gas%20Final%20Report.pdf.  Please note that emissions from downstream filling of tanks in the transport report were excluded. An LCA report from Energija Balkana for the Turkstream pipeline, found at https://energijabalkana.net/wp-content/uploads/2021/10/ts-Sphera-LCA-TurkStream_Final-Report.pdf, was also used as a proxy for Turkish gas as we couldn’t find adequate LCA information for Turkish and Azerbaijani gas shipped through the Trans-Anatolian Pipeline. This is likely a slight overestimate, as it is derived from Russian gas traveling through the Turkstream pipeline. Emissions rates from different segments of the life cycle for each of these gas sources were separated into Territorial and ex-Territorial. All emissions incurred in distribution pipelines or regasification were considered territorial, along with combustion, which was assumed to have an intensity equivalent to 180 kgCO2e/MWh heat. All other emissions were assumed to be upstream.
  
  All emissions for gas produced in Europe was assumed to be Territorial. Since LCA values were only cited for major gas producing countries in the reports used, countries without given LCA values were clustered by their closest major producer and assigned their production LCA value. This shouldn’t have much of an impact due to the lack of production in most countries affected by the clustering. 
  
  Most import sources, transportation/transmission emissions were averaged across regions (SE, SW, Central, and North as listed in the EU report cited) to get an average European emissions rate from that source. An averaged LNG emissions rate was created by weighting various LNG source LCA emissions values using information from the EIA, with US LNG replacing all Russian contributions. All values in the two sheets are in TCO2e/mcm. 100 year GWP was used for all emissions cases. Each model run took in all emissions rates and multiplied them by the imports or production of each importer or member country, divided into territorial and upstream emissions.
  
## Settings Input Files
  RussiaReduc.csv and ReducSelector.csv are the two key settings files in the inputs folder. RussiaReduc.csv modifies the maximum usable proportion of import pipeline capacity from Russia in each month for each country; all cell values should therefore be between 1 and 0. This allows for an nationally disaggregated phase out of Russian gas from European demand sinks. ReducSelector.csv modifies the scale of demand reduction present in each country. Several demand reduction profiles are included in the Inputs folder, each of which can be selected to apply to any or all of the countries included in the model, allowing for modeling of both disorganized and unified demand reductions across the modeled countries. The following demand reduction paths are available without supplementing the existing files.
  - Industry: 0%, 2.5%, 5%
  - Commercial and Residential Heating: 0%, 2%, 4%, 8%, 12%
  - CHP Usage: 0%, 2%, 4%, 8%

# Model Structure Description
  This is a linear programming model designed to represent all key technical constraints of the European gas network at country-level spatial resolution and monthly temporal resolution. The current model setup includes 28 countries over the course of 24 months, the full list of which is included in CountryList.csv. Due to the Ukrainian ban on gas exports and significant uncertainty in Ukrainian gas demand, we specifically exclude Ukrainian gas storage, demand, production, and transmission from consideration (Stuart, 2022). Additionally, due to their objections to the EU oil embargo, we similarly exclude Hungarian and Slovakian storage, demand, and production while allowing the continued use of Hungarian and Slovakian gas transmission by the rest of the European system. It is assumed that Hungary and Slovakia can source all their domestic gas demands through continued imports from Russia. A full printout of the model formulation is available by uncommenting lines 536 and 537 of GasModelV2.jl. For the sake of transparency, the remainder of this ReadMe will be dedicated to exploring the mathematical formulation of key constraints and the objective statement of this model.
  
## Demand Constraints
  Minimum demand levels are enforced by creating both a demand_eq variable, the actual consumption of gas as allowed by the model, and a demand expression, which compiles the various country-level sectoral reductions into the minimum allowable level of demand in a given country in a given month. The demand_eq variable must always be greater than the demand expression. We introduced a shortfall variable here to represent true demand shortfalls.
  
## Storage Constraints
  We constrain the maximum storage fill level to always be below the working gas capacity of all gas storage in a given country. Fill level continutity is provided by a constraint which ensures that the fill level in a given month is equal to the previous month's fill level plus additions and minus withdrawals. We track the fill level both as a proportion of total storage filled, and in terms of mcm gas. Winter fill requirements are implemented in two ways. If the EU 90% storage requirements must be met, the following constraint is implemented: Fill + Gap >= .9 * storage capacity for all countries in October of each year. We construct a scaled storage requirement designed to leverage demand reductions by scaling the 90% storage requirement by the ratio of demand from a given year's winter to winter 2021. It is implemented as follows: Fill + Gap >= 0.9 * demand_current/demand_2021 * storage capacity. The inclusion of a gap is crucial as it allows quantification of storage specific shortfalls as opposed to demand shortfalls. Maximum inject and withdrawal rates are constrained based on data from AGSI.
  
## Import Constraints
  All imports are constrained to be less than or equal to their respective previous winter volumes and upcoming capacity expansions. LNG ports are derated to be usable 97% of the time, however this capacity is rarely fully used in model outputs. Phase-outs and eliminations of Russian gas are imposed by monthly and country level constraints dictated by the RussiaReduc.csv file, with the exception of Bulgaria, Poland, Latvia, Lithuania, and Estonia, which had previously disconnected or been cut off from Russian gas.

## Transmission Constraints
  Transmission continuity is ensured by separately calculating import and export values from each country, constrained to both be less than the derated transmission capacity and equal on both sides of each given transaction.
 
## Balance Constraint
  The overall gas balance was ensured by a constraint that for every country and every month gas was conserved between entities. This required the following:
  $$ shortfall[cc,t] + transmissionin[cc,t] + imports[cc,t] + production[cc,t] + biogas[cc,t] + storagewithdrawals[cc,t] $$
  $$ == demandeq[cc,t] + transmissionout[cc,t] + storageinjections[cc,t] $$

## Objective Statement Design
  As cost is not included in this model, we needed to minimize three things simultaneously. First, the share of Russian gas was minimized with a soft penalty, encouraging the model to push that to zero when it could do so without sacrificing other outcomes. Second, shortfall proportions, characterized as the shortfall for a given country in a given month divided by its demand, in order to avoid dumping shortfalls into small countries without consideration, and to minimize shortfall generally. Third, the storage gap was minimized to penalize not meeting storage goals. A simplified objective statement formulation is as follows, where K = 10^-3 and P = 10^5:
  $$ minimize:  K * totrussia + \sum_{cc}\sum_{t}{P * shortfallprop} + storagegap10 + storagegap22) $$
  
  
