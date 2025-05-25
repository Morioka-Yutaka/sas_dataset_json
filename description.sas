Type : Package
Package : sas_dataset_json
Title : sas_dataset_json--Provides various macros related to support bi-directional conversion between Dataset-JSON forma(version 1.1)t and SAS datasets.
Version : 0.1.2
Author : Yutaka Morioka(sasyupi@gmail.com)
Maintainer : Yutaka Morioka(sasyupi@gmail.com)
License : MIT
Encoding : UTF8
Required : "Base SAS Software"
ReqPackages :  

DESCRIPTION START:
sas_dataset_json is a SAS macro package designed to support bi-directional conversion between CDISC-compliant dataset-JSON format and SAS datasets. 
Key Features:

Export SAS datasets to dataset-JSON

Automatically extracts metadata such as labels, data types, lengths, and formats

Supports SAS Extended Attributes to override default metadata values
(e.g., dataType, displayFormat, label, targetDataType, etc.)

Outputs in strict compliance with dataset-JSON v1.1

Import dataset-JSON into SAS datasets

Parses metadata and records from JSON to reconstruct SAS datasets

DESCRIPTION END:
