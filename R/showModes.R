#' Use the multiple modes of the robust profile likelihood function to find out multiple pathways in MR and their marker SNPs.
#'
#' THis function can be run only for \code{k = 1} when there is only one risk factor
#'
#' @inheritParams grappleRobustEst
#' @param marker.data A list of the data used to find markers. Default is NULL, which is using the same sets of SNPs as find the modes for finding the markers. Another choice is to pass the output \code{marer.data} from the grapple function \code{getInput}. If the user wants to provide his/her own list, then it should be a list containing 4 elements, \code{b_exp}, \code{b_out}, \code{se_exp} and \code{se_out}. This argument is used only when \code{input.list} is NULL. If \code{input.list} is non-null, then \code{marker.data} will be set as \code{input.list$marker.data} regardless of the value of this argument.
#' @param marker.p.thres P-value threshold for marker SNP selection. See \code{p.thres} 
#' @param mode_lmts The range of \code{beta} that the modes are searched from. Default is \code{c(-5, 5)}
#' @param k.findmodes Tuning parameters of the loss function, for loss "l2", it is NA, for loss "huber", default is 1.345 and for loss "tukey", default is 3. 
#' @param beta.mode Allow providing values of the modes to find out marker SNPs for any given modes
#' @param include.thres Absolute value upper threshold of the standardized test statistics of one SNP on one mode for the SNP to be included as a marker for that mode, default is 1.4
#' @param exclude.thres Absolute value lower threshold of the standardized test statistics of one SNP on other modes for the SNP to be included as a marker for that mode, default is \code{qnorm(0.975)}
#' @param map.marker Whether map each marker to the earist gene or not. Default is TRUE if multiple markers are found. It is always FALSE if there is just one mode.
#' @param ldThres the parameter passed to the \code{queryhaploReg} function. Increase to 1 when there is a "timeout" error.
#' @param npoints Number of equally spaced points chosen for grid search of modes within the range \code{mode.lmts}.
#'
#' @return A list containing the following elements:
#' \item{fun}{The profile likelihood function with argument \code{beta}}
#' \item{modes}{The position of modes. Only include modes where marker genes can be detected}
#' \item{p}{The profile likelihood plot with gene markers when there are multiple modes. The range of the x.axis depends on the distance between the maximum mode and minimum mode when there are multiple modes.}
#' \item{markers}{A data frame of marker information}
#' \item{raw.modes}{All modes of the profile likelihood function within the range of \code{mode_lmts}}
#' \item{supp_gwas}{More information about the markers.}
#'
#' @import ggplot2 
#' @importFrom ggrepel geom_text_repel
#' @importFrom haploR queryHaploreg
#' @export
findModes <- function(input.list = NULL,
					  b_exp = NULL, b_out = NULL, 
                      se_exp = NULL, se_out = NULL,
					  p.thres = NULL, 
					  sel.pvals = NULL,
					  marker.data = NULL,      
	  				  marker.p.thres = NULL,	  
					  mode.lmts = c(-5, 5),
                      cor.mat = NULL, 
                      loss.function = c("tukey", "huber", "l2"), 
                      k.findmodes = switch(loss.function[1], 
                                 l2 = NA, huber = 1.345, 
                                 tukey = 3), 
                      beta.mode = NULL,
                      include.thres = 1, exclude.thres = 2,
                      map.marker = T, ldThres = 0.9, #p.thres = NULL, 
					  npoints = 10000) {

	tau2 <- 0

	if (!is.null(input.list)) {
		b_exp <- input.list$b_exp
		b_out <- input.list$b_out
		se_exp <- input.list$se_exp
		se_out <- input.list$se_out
		sel.pvals <- input.list$sel.pvals
		marker.data <- input.list$marker.data
		cor.mat <- input.list$cor.mat
	} else {
		if (is.null(b_exp) || is.null(b_out) || is.null(se_exp) || is.null(se_out))
			stop("Require providing either the input.list or all values of b_exp, b_out,
				 se_exp and se_out")
	}


	b_exp <- as.matrix(b_exp)
	se_exp <- as.matrix(se_exp)
	b_out <- as.vector(b_out)
	se_out <- as.vector(se_out)

	if (ncol(b_exp) > 1)
		stop("Finding modes is currentl available only for 
			 univariate MR with only one risk factor!")


    if (is.null(marker.data)) 
		marker.data <- list(b_exp = b_exp,
							se_sep = se_exp,
							b_out = b_out,
							b_se = b_se,
							sel.pvals = sel.pvals)

	if (!is.null(p.thres)) {
		if (is.null(sel.pvals))
			stop("Please provide the list of p-values for selection")
		else {
			if (length(p.thres == 1))
				idx <- which(sel.pvals < p.thres)
			else if (length(p.thres) == 2)
				idx <- which(sel.pvals >= p.thres[1] & sel.pvals < p.thres[2])
			if (length(p.thres) > 2 || length(idx) == 0)
				stop("Please provide valid p-value thresholds")
		}
	} else
		idx <- 1:nrow(b_exp)

	b_exp <- b_exp[idx, , drop = F]
	se_exp <- se_exp[idx, , drop = F]
	b_out <- b_out[idx]
	se_out <- se_out[idx]

	if (!is.null(marker.p.thres)) {
		if (is.null(marker.data$sel.pvals))
			stop("Please provide the list of p-values for marker selection")
		else {
			if (length(marker.p.thres == 1))
				idx <- which(marker.data$sel.pvals < marker.p.thres)
			else if (length(marker.p.thres) == 2)
				idx <- which(marker.data$sel.pvals >= marker.p.thres[1] & 
							 marker.data$sel.pvals < marker.p.thres[2])
			if (length(marker.p.thres) > 2 || length(idx) == 0)
				stop("Please provide valid p-value thresholds for marker selection.")
		}
	} else
		idx <- 1:nrow(marker.data$b_exp)

	marker.data$b_exp <- marker.data$b_exp[idx, , drop = F]
	marker.data$se_exp <- marker.data$se_exp[idx, , drop = F]
	marker.data$b_out <- marker.data$b_out[idx]
	marker.data$se_out <- marker.data$se_out[idx]



	# b_exp_st <- as.matrix(b_exp_st)
	# se_exp_st <- as.matrix(se_exp_st)

	loss.function <- match.arg(loss.function, c("tukey", "huber", "l2"))
	if (is.null(cor.mat))
		cor.mat <- diag(rep(1, ncol(b_exp) + 1))
	rho <- switch(loss.function,
				  l2 = function(r, ...) rho.l2(r, ...),
				  huber = function(r, ...) rho.huber(r, k.findmodes, ...),
				  tukey = function(r, ...) rho.tukey(r, k.findmodes, ...))

	delta <- integrate(function(x)  rho(x) * dnorm(x), -Inf, Inf)$value

	c1 <- integrate(function(x) rho(x, deriv = 1)^2 * dnorm(x), -Inf, Inf)$value
	c2 <- integrate(function(x) rho(x)^2 * dnorm(x), -Inf, Inf)$value - delta^2
	c4 <- integrate(function(x) rho(x, deriv = 1) * x * dnorm(x), -Inf, Inf)$value
	c3 <- c4


  ## First, calculate t for each SNP
	t_fun <- function(beta, tau2 = 0) {
		upper <- b_out - b_exp %*% beta
		temp <- t(t(cbind(se_exp, se_out)) * c(-beta, 1))
		lower <- sqrt(rowSums((temp %*% cor.mat) * temp) + tau2)
		return(upper/lower)
	}


	t_fun_marker <- function(beta, tau2 = 0) {
			upper <-marker.data$b_out - as.matrix(marker.data$b_exp) %*% beta
			temp <- t(t(cbind(as.matrix(marker.data$se_exp), 
							  marker.data$se_out)) * c(-beta, 1))
			lower <- sqrt(rowSums((temp %*% cor.mat) * temp) + tau2)
		#	print(head(as.vector(upper/lower)))
			return(upper/lower)
		}



	robust.optfun.fixtau <- function(beta, tau2 = 0) {
		-sum(rho(t_fun(beta, tau2)))
	}

	## Take npoints equally spaced points to do grid search to check for modes
	beta.seq <- seq(mode.lmts[1], mode.lmts[2], length.out = npoints)
	val <- sapply(beta.seq, function(beta) robust.optfun.fixtau(beta, tau2))
	mode.pos <- findLocalModes(val)
	temp.data <- data.frame(beta = beta.seq, likelihood = val)

	llk.limit <- range(val)



	if (is.null(beta.mode))
		beta.mode <- beta.seq[mode.pos]

	res.mat <- sapply(beta.mode, function(beta) tt <- t_fun_marker(beta,0))

	if (length(beta.mode) == 1)
		res.mat <- as.matrix(res.mat)

	colnames(res.mat) <- beta.mode

	rownames(res.mat) <- rownames(marker.data$b_exp)

	ss <- which(rowSums(abs(res.mat) < exclude.thres) == 1 & 
				rowSums(abs(res.mat) < include.thres) > 0)

	res.mat <- res.mat[ss, , drop = F]
	markers <- as.data.frame(abs(res.mat) < include.thres)

	keep.mode <- colSums(markers) > 0

	print(paste("The modes of beta are:", paste(beta.mode[keep.mode], collapse = ",")))


	markers <- markers[, keep.mode, drop = F]

	tmp.range <- max(beta.mode) - min(beta.mode)


	tmp.lines <- data.frame(modes = beta.mode[keep.mode],
							mod.col = as.factor(beta.mode[keep.mode]))
	p <- ggplot2::ggplot(aes(x = beta, y = likelihood), data = temp.data) + geom_line() + 
		geom_vline(xintercept = 0) + 
		geom_vline(data = tmp.lines,
				   map = aes(xintercept = modes, color = mod.col), linetype = "dashed") + 
			 geom_vline(xintercept = beta.mode[!keep.mode], color = "gray", linetype = "dashed") + 
			 labs(y = "Profile lieklihood") +
			 # annotate("text", x = mode.lmts[1] * 0.75 + mode.lmts[2] * 0.25,
			 #          y = sum(range(temp.data$likelihood) * c(0.25, 0.75)), 
			 #		   label = paste(length(b_out), "SNPs")) +  
			 theme(axis.line = element_line(linetype = "solid"),          
				   axis.text.y=element_blank(),
				   axis.ticks.y=element_blank(),
				   legend.position="none",
				   panel.background=element_blank(),
				   panel.border=element_blank(),
				   panel.grid.major=element_blank(),
				   panel.grid.minor=element_blank(),
				   plot.background=element_blank(),
				   plot.title=element_text(size = 11))

#  if (!is.null(p.thres))
#	  p <- p + ggtitle(paste0("pvalue threshold:", p.thres))


	if (ncol(markers) <= 1)
		map.marker <- F
	if (map.marker) {

	

		p <- p +  xlim(max(mode.lmts[1], min(beta.mode) -  2 * tmp.range), 
					   min(mode.lmts[2], max(beta.mode) + 2 * tmp.range)) 


		snp_ids <- rownames(markers)

  	## map to HaploReg
	
    results <- queryHaploreg(query = snp_ids, ldThres = ldThres)
	results <- as.data.frame(results[, c("rsID", "chr", "pos_hg38", "GENCODE_name", 
										 "gwas", "dbSNP_functional_annotation",
										 "is_query_snp", "r2")],
							 stringsAsFactors = F)
	tt <- strsplit(results$gwas, split = ";")
	tt <- lapply(tt, function(traits) {
					 trait <- strsplit(traits, split = ",")
					 if (trait[[1]][1] == ".")
						 return(traits)
					 trait_name <- sapply(trait, function(item) item[2])
					 pvalues <- sapply(trait, function(item) as.numeric(item[3]))
					 return(paste0(unique(trait_name[sort(pvalues, index.return = T)$ix]), collapse = ","))				 
							 })
	results$gwas_short <- tt
	results.supp <- results[results$is_query_snp == 0 & results$gwas != ".", ]
	results <- results[results$is_query_snp == 1, ]
	ss <- subset(results, select = c(gwas, dbSNP_functional_annotation))
	results <- subset(results, select = -c(gwas, dbSNP_functional_annotation, is_query_snp, r2))
	results.supp <- subset(results.supp, select = -is_query_snp)
	results.supp <- results.supp[order(results.supp$GENCODE_name), ]

	markers <- cbind(markers, res.mat)
	colnames(markers) <- c(paste0("Mode", 1:sum(keep.mode), "_marker"), 
						   paste0("Mode", 1:sum(keep.mode), "_stats"))
    markers <- cbind(results, data.frame(markers)[results$rsID, ], ss)
	res.mat <- data.frame(res.mat)[markers$rsID, ]

  } else {
	  markers	<- cbind(markers, res.mat)
	  colnames(markers) <- c("Mode1_marker", "Mode1_stats")
	  results.supp <- NULL
  }

  #   print(markers)

 
  res.mat.ranking <- data.frame(res.mat)
  res.mat.ranking[abs(res.mat) > include.thres] <- Inf
  res.mat.ranking <- abs(res.mat.ranking)

  try(markers <- markers[do.call("order", 
								 res.mat.ranking[, 1:sum(keep.mode), drop = F]),, drop = F])

  try(res.mat <- res.mat[do.call("order", 
								 res.mat.ranking[, 1:sum(keep.mode), drop = F]),, drop = F])

 
  if (sum(keep.mode) > 1) {
	  names(marker.data$b_out) <- rownames(marker.data$b_exp)
	  marker.ratio <- marker.data$b_out[markers$rsID] / marker.data$b_exp[markers$rsID, 1]
	  marker.mode <- as.matrix(markers[, 6:(5 + sum(keep.mode)), drop = F]) %*% 
		  as.matrix(beta.mode[keep.mode])
  	  markers <- cbind(markers[, 1:4], marker.est = marker.ratio,
						 mode = marker.mode, markers[, -(1:4)])

	  tmp.est <- data.frame(x = marker.ratio, col = as.factor(marker.mode),
							y = rep(0.9 * llk.limit[1] + 0.1 * llk.limit[2], length(marker.ratio)),
							genes = markers$GENCODE_name)
	  idx <- rep(T, nrow(tmp.est))
	  for (i in 2:nrow(tmp.est)) {
		  ii <- which(tmp.est$genes[1:(i - 1)] == tmp.est$genes[i])
	  	if (length(ii) >= 1 && tmp.est$col[i] == tmp.est$col[max(ii)])
			idx[i] <- F
	  }
	  tmp.est1 <- tmp.est[idx, ]

	  p <- p + geom_point(data = tmp.est, mapping = aes(x = x, y= y, col = col, 
														fill = col), shape = "|", size = 2) + 
		  geom_text_repel(data = tmp.est1, mapping = aes(x= x, y= y, label = genes, 
														 col = col), inherit.aes = F)
		   
  }

  return(list(fun = robust.optfun.fixtau,
              modes = beta.mode[keep.mode],
              raw.modes = beta.mode, 
              p = p,
              markers = markers,
			  supp_gwas = results.supp))
}


#' findLocal maximum modes of a series of points
#'
#' @keywords internal
#' 
findLocalModes <- function(v, npts = 21) {
  v.temp <- c(rep(0, npts), v, rep(0, npts))

  idx <- c(1:npts, 1:npts + npts + 1)
  #  print(idx)
  judge <- sapply(idx, function(i) v - v.temp[i:(length(v) + i -1)] > 0)
  modes <- rowSums(judge) == ncol(judge)
  return(which(modes))
}




