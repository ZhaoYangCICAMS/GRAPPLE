% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/harmonize.R
\name{harmonise_data}
\alias{harmonise_data}
\title{Harmonise the alleles and effects between the exposure and outcome}
\usage{
harmonise_data(exposure_dat, outcome_dat, action = 2)
}
\arguments{
\item{exposure_dat}{Output from \code{read_exposure_data}}

\item{outcome_dat}{Output from \code{extract_outcome_data}}

\item{action}{Level of strictness in dealing with SNPs. 1=Assume all reference alleles are on the positive strand, i.e. do nothing (warning - this is very risky and is not recommended); 2=Try to infer positive strand alleles, using allele frequencies for palindromes; 3=Correct strand for non-palindromic SNPs, and drop all palindromic SNPs from the analysis. If a single value is passed then this action is applied to all outcomes. But multiple values can be supplied as a vector, each element relating to a different outcome.}
}
\value{
Data frame with harmonised effects and alleles
}
\description{
In order to perform MR the effect of a SNP on an outcome and exposure must be harmonised to be
relative to the same allele.
}
\details{
Expects data in the format generated by \code{read_exposure_data} and \code{extract_outcome_data}. 
This means the inputs must be dataframes with the following columns:
\code{outcome_dat}:
- SNP
- beta.outcome
- se.outcome
- effect_allele.outcome
- other_allele.outcome
- eaf.outcome
- outcome

\code{exposure_dat}:
- SNP
- beta.exposure
- se.exposure
- effect_allele.exposure
- other_allele.exposure
- eaf.exposure
}
\keyword{internal}
