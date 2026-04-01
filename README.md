# ECAD

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://arnaud-ma.github.io/ECAD.jl/stable/) [![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://arnaud-ma.github.io/ECAD.jl/dev/) [![Build Status](https://github.com/arnaud-ma/ECAD.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/arnaud-ma/ECAD.jl/actions/workflows/CI.yml?query=branch%3Amain) [![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl) [![code style: runic](https://img.shields.io/badge/code_style-%E1%9A%B1%E1%9A%A2%E1%9A%BE%E1%9B%81%E1%9A%B2-black)](https://github.com/fredrikekre/Runic.jl)

> [!WARNING]
> ECA&D has a data policy that you can find [here](https://knmi-ecad-assets-prd.s3.amazonaws.com/documents/ECAD_datapolicy.pdf). To summarize, cite them, use only for non-commercial research and educational purposes, and submit scientific results based on these data for publication for the open literature without delay.

A Julia package to access blended daily public weather data from [eca&d](https://www.ecad.eu/).

Automatically download, parse and load the data you want into a `DataFrame`.

# Example

Let's take the example of the maximum temperature and precipitation variables in France.

> [!NOTE]
> We use the `warn_multiple_elements = false` for convenience, but the warnings are there for a reason. If
> the warning appears for a given station, it means that there is multiple units / way of measuring the variable for that station (for example, the mean temperature can be calculated from the max and min temperature, but it can also be measured directly). In that case, you should check the station info and the `load_elements(variable)` function.

```julia-repl
julia> using ECAD, DataFramesMeta

julia> summary_variables()
Table with 4 columns and 14 rows:
      variable                      longname                      canonical_NAME  sha
    ┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
 1  │ CloudCover()                  cloud_cover                   CC              nothing
 2  │ GlobalRadiation()             global_radiation              QQ              nothing
 3  │ Humidity()                    humidity                      HU              nothing
 4  │ MaximumHourlyPrecipitation()  maximum_hourly_precipitation  RHX             nothing
 5  │ MaximumTemperature()          maximum_temperature           TX              8249f3ed31b2a94b3649dd8660f5b7f21cd235dd1733e3b3edd0855d9726cae9
 6  │ MeanTemperature()             mean_temperature              TG              nothing
 7  │ MinimumTemperature()          minimum_temperature           TN              447e11a903490b63e9b159530a12dd60a80b8f9e55c8dec6ce861c310e2e2d4c
 8  │ PrecipitationAmount()         precipitation_amount          RR              nothing
 9  │ SeaLevelPressure()            sea_level_pressure            PP              5450696a0df010a9e9e2b0d063d4054caab3bec28b68439fe55c73c5214686c4
 10 │ SnowDepth()                   snow_depth                    SD              5100f26849dfbf01f38c612b987aad39b3b49acf5127b2f2c1d8ed604522b493
 11 │ SunshineDuration()            sunshine_duration             SS              nothing
 12 │ WindDirection()               wind_direction                DD              nothing
 13 │ WindGust()                    wind_gust                     FX              nothing
 14 │ WindSpeed()                   wind_speed                    FG              nothing

julia> variables = [:tx, :rr]  # can be the variable or the canonical name
2-element Vector{Symbol}:
 :tx
 :rr

julia> variables_data = VariableData.(variables) # asks you if you want to automatically download the data if not already available.
2-element Vector{VariableData{Vector{UInt8}}}:
 VariableData(variable=ECAD.MaximumTemperature(), name=TX, zip="ECA_blend_tx.zip", entries=9183)
 VariableData(variable=ECAD.PrecipitationAmount(), name=RR, zip="ECA_blend_rr.zip", entries=17611)

julia> stations = intersect_stations(variables_data)
8087×6 DataFrame
  Row │ id     name                   country_code  latitude_arcsec  longitude_arcsec  height_meter
      │ Int64  String                 String3       Int64            Int64             Int64
──────┼─────────────────────────────────────────────────────────────────────────────────────────────
    1 │     1  VAEXJOE                SE                     204720             53280           166
    2 │     2  FALUN                  SE                     218220             56220           160
    3 │     3  STENSELE               SE                     234240             61799           325
    4 │     4  LINKOEPING             SE                     210240             55919            93
    5 │     5  LINKOEPING-MALMSLAETT  SE                     210240             55919            93
    6 │     6  KARLSTAD               SE                     213660             48480            46
    7 │     7  KARLSTAD-AIRPORT       SE                     214000             48015           107
    8 │     8  OESTERSUND             SE                     227459             52139           376
  ⋮   │   ⋮              ⋮                 ⋮               ⋮                ⋮               ⋮
 8081 │ 28431  HEIDARBAER             IS                     231120            -74761           125
 8082 │ 28432  IRAFOSS                IS                     230717            -75576            66
 8083 │ 28433  REYKIR I OLFUSI        IS                     230400            -74941            51
 8084 │ 28755  HESKESTAD              NO                     210503             22907           165
 8085 │ 28762  NYSET                  NO                     220185             27902           983
 8086 │ 28765  MATARO                 ES                     149563              8759            87
 8087 │ 28766  PERAFITA               ES                     151341              7632           774
                                                                                   8072 rows omitted

julia> stations = @rsubset(stations, :country_code == "FR")
43×6 DataFrame
 Row │ id     name                            country_code  latitude_arcsec  longitude_arcsec  height_meter
     │ Int64  String                          String3       Int64            Int64             Int64
─────┼──────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │    31  MARSEILLE OBS. PALAIS-LONCHAMP  FR                     155898             19428            75
   2 │    32  BOURGES                         FR                     169413              8494           161
   3 │    33  TOULOUSE-BLAGNAC                FR                     157035              4964           151
   4 │    34  BORDEAUX-MERIGNAC               FR                     161390              2489            47
   5 │    36  PERPIGNAN                       FR                     153853             10342            42
   6 │    37  LYON - ST EXUPERY               FR                     164615             18280           235
   7 │    39  MARIGNANE                       FR                     156376             18777             9
   8 │   322  RENNES-ST JACQUES               FR                     173048              -958            36
  ⋮  │   ⋮                  ⋮                      ⋮               ⋮                ⋮               ⋮
  37 │ 11243  TROYES-BARBEREY                 FR                     173968             14471           112
  38 │ 11244  PTE DE CHASSIRON                FR                     165768             -2118            11
  39 │ 11245  PLOUMANAC'H                     FR                     175772             -9097            55
  40 │ 11246  NANCY-OCHEY                     FR                     174891             21454           336
  41 │ 11247  BELLE ILE - LE TALUT            FR                     170259            -10015            34
  42 │ 11248  CAP CEPET                       FR                     155085             21386           115
  43 │ 11249  ORLY                            FR                     175380              8583            89
                                                                                             28 rows omitted

julia> stations_data = StationData.(Ref(variables_data), stations.id; warn_multiple_elements = false)
43-element Vector{StationData}:
 StationData(id=31, name="MARSEILLE OBS. PALAIS-LONCHAMP", lat=155898 arcsec, lon=19428 arcsec, elev=75 m, vars=[ECAD.MaximumTemperature(), ECAD.PrecipitationAmount()], rows=53019, cols=8)
 StationData(id=32, name="BOURGES", lat=169413 arcsec, lon=8494 arcsec, elev=161 m, vars=[ECAD.MaximumTemperature(), ECAD.PrecipitationAmount()], rows=29585, cols=8)
 StationData(id=33, name="TOULOUSE-BLAGNAC", lat=157035 arcsec, lon=4964 arcsec, elev=151 m, vars=[ECAD.MaximumTemperature(), ECAD.PrecipitationAmount()], rows=28914, cols=8)
 StationData(id=34, name="BORDEAUX-MERIGNAC", lat=161390 arcsec, lon=2489 arcsec, elev=47 m, vars=[ECAD.MaximumTemperature(), ECAD.PrecipitationAmount()], rows=38471, cols=8)
 StationData(id=36, name="PERPIGNAN", lat=153853 arcsec, lon=10342 arcsec, elev=42 m, vars=[ECAD.MaximumTemperature(), ECAD.PrecipitationAmount()], rows=37010, cols=8)
 StationData(id=37, name="LYON - ST EXUPERY", lat=164615 arcsec, lon=18280 arcsec, elev=235 m, vars=[ECAD.MaximumTemperature(), ECAD.PrecipitationAmount()], rows=18597, cols=8)
 StationData(id=39, name="MARIGNANE", lat=156376 arcsec, lon=18777 arcsec, elev=9 m, vars=[ECAD.MaximumTemperature(), ECAD.PrecipitationAmount()], rows=38410, cols=8)
 StationData(id=322, name="RENNES-ST JACQUES", lat=173048 arcsec, lon=-958 arcsec, elev=36 m, vars=[ECAD.MaximumTemperature(), ECAD.PrecipitationAmount()], rows=29705, cols=8)
 StationData(id=323, name="STRASBOURG-ENTZHEIM", lat=174777 arcsec, lon=27505 arcsec, elev=150 m, vars=[ECAD.MaximumTemperature(), ECAD.PrecipitationAmount()], rows=37560, cols=8)
 StationData(id=434, name="BREST-GUIPAVAS", lat=174399 arcsec, lon=-12918 arcsec, elev=94 m, vars=[ECAD.MaximumTemperature(), ECAD.PrecipitationAmount()], rows=29644, cols=8)
 ⋮
 StationData(id=2207, name="MONTPELLIER-AEROPORT", lat=156876 arcsec, lon=14267 arcsec, elev=2 m, vars=[ECAD.MaximumTemperature(), ECAD.PrecipitationAmount()], rows=29279, cols=8)
 StationData(id=2209, name="AJACCIO", lat=150905 arcsec, lon=31654 arcsec, elev=5 m, vars=[ECAD.MaximumTemperature(), ECAD.PrecipitationAmount()], rows=27910, cols=8)
 StationData(id=11243, name="TROYES-BARBEREY", lat=173968 arcsec, lon=14471 arcsec, elev=112 m, vars=[ECAD.MaximumTemperature(), ECAD.PrecipitationAmount()], rows=18567, cols=8)
 StationData(id=11244, name="PTE DE CHASSIRON", lat=165768 arcsec, lon=-2118 arcsec, elev=11 m, vars=[ECAD.MaximumTemperature(), ECAD.PrecipitationAmount()], rows=51864, cols=8)
 StationData(id=11245, name="PLOUMANAC'H", lat=175772 arcsec, lon=-9097 arcsec, elev=55 m, vars=[ECAD.MaximumTemperature(), ECAD.PrecipitationAmount()], rows=28702, cols=8)
 StationData(id=11246, name="NANCY-OCHEY", lat=174891 arcsec, lon=21454 arcsec, elev=336 m, vars=[ECAD.MaximumTemperature(), ECAD.PrecipitationAmount()], rows=23070, cols=8)
 StationData(id=11247, name="BELLE ILE - LE TALUT", lat=170259 arcsec, lon=-10015 arcsec, elev=34 m, vars=[ECAD.MaximumTemperature(), ECAD.PrecipitationAmount()], rows=35033, cols=8)
 StationData(id=11248, name="CAP CEPET", lat=155085 arcsec, lon=21386 arcsec, elev=115 m, vars=[ECAD.MaximumTemperature(), ECAD.PrecipitationAmount()], rows=20970, cols=8)
 StationData(id=11249, name="ORLY", lat=175380 arcsec, lon=8583 arcsec, elev=89 m, vars=[ECAD.MaximumTemperature(), ECAD.PrecipitationAmount()], rows=38351, cols=8)

julia> stations_data[5]
StationData:
├ ID: 36
├ Name: PERPIGNAN
├ Coordinates: lat=153853 arcsec, lon=10342 arcsec
├ Elevation: 42 m
├ Variables (2): ECAD.MaximumTemperature(), ECAD.PrecipitationAmount()
├ Observations: 37010 rows × 8 cols
├ Date range: 1924-11-01 -> 2026-02-28
└ Columns: station_id, date, tx, tx_quality, tx_element_id, rr, rr_quality, rr_element_id

julia> stations_data[5].observations
37010×8 DataFrame
   Row │ station_id  date        tx       tx_quality  tx_element_id  rr       rr_quality  rr_element_id
       │ Int64       Date        Int64?   String?     String7?       Int64?   String?     String7?
───────┼────────────────────────────────────────────────────────────────────────────────────────────────
     1 │         36  1924-11-01  missing  missing     TX6            missing  missing     RR9
     2 │         36  1924-11-02  missing  missing     TX6            missing  missing     RR9
     3 │         36  1924-11-03  missing  missing     TX6            missing  missing     RR9
     4 │         36  1924-11-04  missing  missing     TX6            missing  missing     RR9
     5 │         36  1924-11-05  missing  missing     TX6            missing  missing     RR9
     6 │         36  1924-11-06  missing  missing     TX6            missing  missing     RR9
     7 │         36  1924-11-07  missing  missing     TX6            missing  missing     RR9
     8 │         36  1924-11-08  missing  missing     TX6            missing  missing     RR9
   ⋮   │     ⋮           ⋮          ⋮         ⋮             ⋮           ⋮         ⋮             ⋮
 37004 │         36  2026-02-22      215  valid       TX6                  0  valid       RR9
 37005 │         36  2026-02-23      227  valid       TX6                  0  valid       RR9
 37006 │         36  2026-02-24      206  valid       TX6                  0  valid       RR9
 37007 │         36  2026-02-25      139  valid       TX6                  0  valid       RR9
 37008 │         36  2026-02-26      171  valid       TX6                  0  valid       RR9
 37009 │         36  2026-02-27      136  valid       TX6                  4  valid       RR9
 37010 │         36  2026-02-28      157  valid       TX6                  2  valid       RR9
                                                                                      36995 rows omitted
```


# References

We acknowledge the data providers in the ECA&D project.
Klein Tank, A.M.G. and Coauthors, 2002. Daily dataset of 20th-century surface air
temperature and precipitation series for the European Climate Assessment. Int. J. of Climatol.,
22, 1441-1453.
Data and metadata available at https://www.ecad.eu