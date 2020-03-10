#' Blind cross validation for random forest
#'
#' Grows multiple random forests with blind cross validation: the algorithm is trained
#' a specific part of the dataset, and prediction are done on another part of the dataset.
#'
#' @param tab An abundance table containing samples in columns and OTUs/ASV in rows.
#' @param treat A vector containing the class identity of each sample.
#' @param train.id A charecter sting to be searched in samples names that will be used for training.
#' @param mtry The mtry parameter to be passed to the \code{ranger} function.
#' See \code{ranger} documentation for details.
#' @param n.tree The number of tree to grow. The default is \code{500}.
#' @param n.forest The number of forests to grow. The default is \code{100}.
#' @param seed A number to set seed before sampling samples in the n-folding process
#' and before growing each forest. The default is \code{NA}.
#'
#'
#' @return Returns a list object containing the confusion matrix, the error rate, the sensitivity
#' the precision as well as the variable importance obtained for each of the \code{n.forest} grown
#' forests.
#'
#' @import ranger

# 2020-02-27
# Marine C. Cambon

rf.blind <- function(tab, treat,
                     train.id = NA,
                     mtry = NULL,
                     n.tree = 500,
                     n.forest = 100) {
  train.idx <- grep(train.id, colnames(tab))
  tab <- data.frame("treat" = treat, t(tab))
  train <- tab[train.idx, ]
  test <- tab[-train.idx, ]
  pred.irri <- error <- rate <- NULL
  res <- data.frame()
  importance <- list()
  for (i in 1:n.forest) {
    message("Growing forest number ", i, "...")
    #set.seed(140)
    rg.irri <- ranger::ranger(treat ~ ., data = train,
                      num.trees = n.tree,
                      mtry = mtry,
                      importance = "impurity")

    pred.irri <- stats::predict(rg.irri, data = test)
    error <- data.frame(table(pred.irri$predictions, test$treat))
    err_rate <- sum(test$treat != pred.irri$predictions)/nrow(test)
    TN <- error[error$Var1=="irr" & error$Var2=="irr","Freq"]
    TP <- error[error$Var1=="non-irr" & error$Var2=="non-irr","Freq"]
    FN <- error[error$Var1=="non-irr" & error$Var2=="irr","Freq"]
    FP <- error[error$Var1=="irr" & error$Var2=="non-irr","Freq"]
    sensitivity <- TP/(TP+FN)
    precision <- TP/(TP+FP)
    res <- rbind(res, cbind(TP, TN, FP, FN, err_rate, sensitivity, precision))
    importance[[i]] <- rg.irri$variable.importance
  }
  summary <- rbind(apply(res,2,mean),apply(res,2,sd))
  rownames(summary) <- c("mean", "sd")

  res_tot <- list(summary, res, importance)
  names(res_tot) <- c("summary", "confusion", "importance")
  return(res_tot)
}