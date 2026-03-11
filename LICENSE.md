# MIT License

Copyright (c) 2026 Will Hardy

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the
“Software”), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

------------------------------------------------------------------------

## Bundled data licence

The `dmd_master` dataset bundled in this package (`data/dmd_master.rda`)
is derived from the **NHS Dictionary of Medicines and Devices (dm+d)**,
published by the **NHS Business Services Authority (NHSBSA)**.

© Crown copyright. Licensed under the **Open Government Licence v3.0**.
<https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/>

The dm+d data is available from the NHSBSA TRUD service:
<https://isd.digital.nhs.uk/trud/users/guest/filters/0/categories/6>

The Open Government Licence is compatible with the MIT licence above.
The MIT licence applies to the package **source code**; the OGL v3.0
applies to the **bundled dm+d data**.

------------------------------------------------------------------------

## NHS Cost Inflation Index data licence

The NHS Cost Inflation Index (NHS CII) rates embedded in this package
(in `R/nhscii.R`) are derived from:

> Jones KC, Weatherly H, Birch S, Castelli A, Chalkley M, Dargan A,
> Findlay D, Gao M, Hinde S, Markham S, Smith D, Teo H (2025). *Unit
> Costs of Health and Social Care 2024 Manual*. Personal Social Services
> Research Unit (University of Kent) & Centre for Health Economics
> (University of York), Kent, UK.
> <https://doi.org/10.22024/UniKent/01.02.109563>

This work is licensed under **Creative Commons
Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA
4.0)**: <https://creativecommons.org/licenses/by-nc-sa/4.0/>

**Important:** The CC BY-NC-SA 4.0 licence prohibits commercial use and
requires any derivative work to be distributed under the same licence.
This restriction applies to any use of the NHS CII rates
(e.g. [`nhscii()`](https://w-hardy.github.io/dmdprices/reference/nhscii.md),
[`inflate_nhscii()`](https://w-hardy.github.io/dmdprices/reference/inflate_nhscii.md),
[`run_inflate_nhscii()`](https://w-hardy.github.io/dmdprices/reference/run_inflate_nhscii.md),
and any output derived from them), regardless of the MIT licence that
covers the package source code.

The MIT licence applies to the package code only. Where PSSRU-derived
data are used, the CC BY-NC-SA 4.0 terms govern.
