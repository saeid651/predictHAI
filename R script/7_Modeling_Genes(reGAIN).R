#
# 
# Statistical Modeling of three data sets (Baylor, Emory (2007-2011), and Mayo)
# Data titers are divided in three groups using GMM method with all baseline HAI only
# All analysis are in log2 scale
#
# Developed By: Saeid Parvandeh Feb 2017
# 
# ---------------------------------------------------------------------------------
rm(list=ls())

library(glmnet)
library(ggplot2)
library(hydroGOF)
library(mixtools)
library(reshape)
library(gridExtra)

# read Baylor titers
load("baylor_titers.RData")
bay.d0 <- baylor_titers$Matched.Max.day0
bay.d28 <- baylor_titers$Max.day28
bay.age <- baylor_titers$Age
bay.max.fc <- baylor_titers$MAX.FC
bay.fc <- bay.max.fc
# log2 scale
bay.d0.log2 <- log2(bay.d0)
bay.d28.log2 <- log2(bay.d28)
bay.fc.log2 <- log2(bay.fc)

# read Emory titers
load("emory_titers.RData")
emory.d0 <- emory_titers$Matched.Max.day0
emory.d28 <- emory_titers$MAX.day28
emory.age <- emory_titers$age_reported
emory.max.fc <- emory_titers$MAX.FC
emory.fc <- emory.max.fc
# log2 scale
emory.d0.log2 <- log2(emory.d0)
emory.d28.log2 <- log2(emory.d28)
emory.fc.log2 <- log2(emory.fc)

# read Mayo titers
load("mayo_titers.RData")
mayo.d0 <- mayo_titers$day0
mayo.d28 <- mayo_titers$day28
mayo.fc <- mayo.d28/mayo.d0
# log2 scale
mayo.d0.log2 <- log2(mayo.d0)
mayo.d28.log2 <- log2(mayo.d28)
mayo.fc.log2 <- log2(mayo.fc)

# compute fold change residuals
bay.df <- data.frame(fc = bay.fc.log2, d0 = bay.d0.log2)
bay.logfit <- lm(fc~d0, data = bay.df)
bay.logfit.sum <- summary(bay.logfit)
cat("R-squared")
bay.logfit.sum$r.squared
cat("RMSD")
sqrt(mean((bay.logfit.sum$residuals)^2))
rmse(bay.logfit$fitted.values, bay.fc.log2)
a<-bay.logfit$coefficients[1]
b<-bay.logfit$coefficients[2]

# Baylor fold-change residuals
bay.fc.log2.resid <- as.vector(bay.logfit$residuals)
# Making sure that our calculation generate correct residual values
bay.fc.log2.resid <- bay.fc.log2 - (a + b*bay.d0.log2)

# Emory fold change residuals
emory.fc.log2.resid <- emory.fc.log2 - (a + b*emory.d0.log2)

# Mayo fold change residuals
mayo.fc.log2.resid <- mayo.fc.log2 - (a + b*mayo.d0.log2)

plot(bay.d0.log2, bay.fc.log2.resid, main = "Baylor residuals vs. Baylor Day0 (Log2 Scale)")
abline(h = 0, col = "red")

plot(emory.d0.log2, emory.fc.log2.resid, main = "Emory residuals vs. Emory Day0 (Log2 Scale)")
abline(h = 0, col = "red")

plot(mayo.d0.log2, mayo.fc.log2.resid, main = "Mayo residuals vs. Mayo Day0 (Log2 Scale)")
abline(h = 0, col = "red")

# load 5000 filtered genes obtained by Coeffecient of Variation
load("B_ex.cv.fltr.RData")
load("E_ex.cv.fltr.RData")
load("M_ex.cv.fltr.RData")

#### ---- Gussian Mixture Model (GMM) day-0 grouping ---- ####
# Combine Baylor, Emory and Mayo data - EM/GMM clustering
# Cutoff points should not be greater than any data titers, because we want to create three groups of each data
com.bay.emory.mayo <- c(bay.d0.log2, emory.d0.log2, mayo.d0.log2)

cutpoints <- c(max(bay.d0.log2), max(bay.d0.log2), max(bay.d0.log2))
condition <- "-Inf"
while(any(condition=="-Inf") | cutpoints[2] >= max(bay.d0.log2) | cutpoints[2] < .9*max(bay.d0.log2)) #
{
  bay.emory.mayo.gmm_clust <- normalmixEM(com.bay.emory.mayo, k=3)#, arbvar = F, epsilon = 1e-03)
  posterior.prob <- data.frame(bay.emory.mayo.gmm_clust$posterior) 
  cutpoints <- sort(c(max(com.bay.emory.mayo[which(colnames(posterior.prob)[apply(posterior.prob,1,which.max)]=="comp.1")])
                      , max(com.bay.emory.mayo[which(colnames(posterior.prob)[apply(posterior.prob,1,which.max)]=="comp.2")])
                      , max(com.bay.emory.mayo[which(colnames(posterior.prob)[apply(posterior.prob,1,which.max)]=="comp.3")])))
  condition <- cutpoints
  cutpoints <- cutpoints
}
clust_cutpoints <- cutpoints
clust_cutpoints

plot(bay.emory.mayo.gmm_clust,which=2, axes=FALSE, main2 ="EM/GMM Clustering of All Day0 HAI Data", 
     cex.main = 1, xlab2 ="Combined log2(Day0) HAI",cex.lab = 1)
axis(side = 1, at = seq(0, 10, .5), cex.axis=1, las=2)
axis(side = 2, cex.axis=1)
abline(v=clust_cutpoints[1], col = "purple", lty = 2)
abline(v=clust_cutpoints[2], col = "purple", lty = 2)
legend(8,.2,c("Lower Baseline Titer Group","Intermediate Baseline Titer Group","Higher Baseline Titer Group","Cluster Boundaries"), 
       lty=c(1, 1, 1, 2), col=c("red","green","blue","purple"), cex=1, bty="n")


#### ---- Feature selection using nested CV based on highest interaction value from reGAIN ---- ####
load("baylor_features.RData")
flu_ncv_features <- NULL
for (i in 1:10){
  for(j in 1:10){
    flu_ncv_features <- c(flu_ncv_features, baylor_features[[i]][[j]])
  }
}

# Count the number of genes
all_genes <- unique(flu_ncv_features)
num_gene <- NULL
for (g in all_genes){
  num_gene <- c(num_gene, length(which(flu_ncv_features==g)))
}
num_gene_count <- data.frame(all_genes, num_gene)
bay_tg <- as.character(num_gene_count[order(num_gene_count$num_gene, decreasing = T), 1][1:200])

### extract top genes from the 1000 filtered genes and calculate their ratio
# Baylor
quotient <- function(x){x[1]/x[2]}
bay.tg.expr <- B_ex.cv.fltr[, bay_tg]
bay.pair.tg <- t(apply(bay.tg.expr, 1, combn, 2, quotient))
colnames(bay.pair.tg) <- apply(combn(colnames(bay.tg.expr),2), 2, paste0,collapse="/")
bay.tg_pair <- cbind(bay.tg.expr, bay.pair.tg)
# Emory
emory.tg.expr <- E_ex.cv.fltr[, bay_tg]
emory.pair.tg <- t(apply(emory.tg.expr, 1, combn, 2, quotient))
colnames(emory.pair.tg) <- apply(combn(colnames(emory.tg.expr),2), 2, paste0,collapse="/")
emory.tg_pair <- cbind(emory.tg.expr, emory.pair.tg)
# Mayo
mayo.tg.expr <- M_ex.cv.fltr[, bay_tg]
mayo.pair.tg <- t(apply(mayo.tg.expr, 1, combn, 2, quotient))
colnames(mayo.pair.tg) <- apply(combn(colnames(mayo.tg.expr),2), 2, paste0,collapse="/")
mayo.tg_pair <- cbind(mayo.tg.expr, mayo.pair.tg)

### --- Day-0 group1 modeling ---- ###
# Baylor group 1
bay.d0.lr.idx <- which(bay.d0.log2 <= clust_cutpoints[1])
bay.d0.lr <- bay.d0[bay.d0.lr.idx]
bay.fc.lr <- bay.fc[bay.d0.lr.idx]
bay.d0.log2.lr <- bay.d0.log2[bay.d0.lr.idx]
bay.fc.log2.lr <- bay.fc.log2[bay.d0.lr.idx]
bay.fc.log2.resid.lr <- bay.fc.log2.resid[bay.d0.lr.idx]

# Fit data with glmnet
bay.glmnet.fit1 <- cv.glmnet(bay.tg.expr[bay.d0.lr.idx, ], bay.fc.log2.resid.lr, alpha = 0)
bay.lambda <- bay.glmnet.fit1$lambda.min
# Feature selection
coef <- predict(bay.glmnet.fit1, s = bay.lambda, type = "coefficients")
selected_features <- names(which(abs(coef[-1,1]) > 0))
selected_features <- grep("Intercept", selected_features, invert = TRUE, value = TRUE)

# Predict on the Baylor
bay.pred.log2.resid.lr <- predict(bay.glmnet.fit1, s = bay.lambda, newx = bay.tg.expr[bay.d0.lr.idx, ])

# Predicted vs observed-residuals scale
bay.lm.model_1 <- lm(bay.pred.log2.resid.lr ~ bay.fc.log2.resid.lr)

# Predicted vs observed-log2 scale
bay.pred.log2.lr  <- bay.pred.log2.resid.lr + (a + b * bay.d0.log2.lr) # Y <- residuals + Y.hat
bay.lm.model_2 <- lm(bay.pred.log2.lr ~ bay.fc.log2.lr)

bay.log2_group.1 <- data.frame(obs=bay.fc.log2.lr, X1 = bay.pred.log2.lr)
bay_group.1 <- data.frame(d0=bay.d0.log2.lr, fc=bay.fc.log2.lr, X1 =bay.pred.log2.lr)


# Emory group1
emory.d0.lr.idx <- which(emory.d0.log2 <= clust_cutpoints[1])
emory.d0.lr <- emory.d0[emory.d0.lr.idx]
emory.fc.lr <- emory.fc[emory.d0.lr.idx]
emory.d0.log2.lr <- emory.d0.log2[emory.d0.lr.idx]
emory.fc.log2.lr <- emory.fc.log2[emory.d0.lr.idx]
emory.fc.log2.resid.lr <- emory.fc.log2.resid[emory.d0.lr.idx]

# Predict on the Emory
emory.pred.log2.resid.lr <- predict(bay.glmnet.fit1, s = bay.lambda, newx = emory.tg.expr[emory.d0.lr.idx, ])

# Predicted vs observed-residuals scale
emory.lm.model_1 <- lm(emory.pred.log2.resid.lr ~ emory.fc.log2.resid.lr)
emory.lr.r2 <- summary(emory.lm.model_1)$r.squared

# Predicted vs observed-log2 scale
emory.pred.log2.lr  <- emory.pred.log2.resid.lr + (a + b*emory.d0.log2.lr) # Y <- residuals + Y.hat
emory.lm.model_2 <- lm(emory.pred.log2.lr ~ emory.fc.log2.lr)

emory.log2_group.1 <- data.frame(obs = emory.fc.log2.lr , X1 = emory.pred.log2.lr)
emory_group.1 <- data.frame(d0=emory.d0.log2.lr, fc=emory.fc.log2.lr, X1 =emory.pred.log2.lr)

# Mayo group1
mayo.d0.lr.idx <- which(mayo.d0.log2 <= clust_cutpoints[1])
mayo.d0.lr <- mayo.d0[mayo.d0.lr.idx]
mayo.fc.lr <- mayo.fc[mayo.d0.lr.idx]
mayo.d0.log2.lr <- mayo.d0.log2[mayo.d0.lr.idx]
mayo.fc.log2.lr <- mayo.fc.log2[mayo.d0.lr.idx]
mayo.fc.log2.resid.lr <- mayo.fc.log2.resid[mayo.d0.lr.idx]

# Predict on the mayo
mayo.pred.log2.resid.lr <- predict(bay.glmnet.fit1, s = bay.lambda, newx = mayo.tg.expr[mayo.d0.lr.idx, ])

# Predicted vs observed-residuals scale
mayo.lm.model_1 <- lm(mayo.pred.log2.resid.lr ~ mayo.fc.log2.resid.lr)
mayo.lr.r2 <- summary(mayo.lm.model_1)$r.squared

# Predicted vs observed-log2 scale
mayo.pred.log2.lr  <- mayo.pred.log2.resid.lr + (a + b*mayo.d0.log2.lr) # Y <- residuals + Y.hat
mayo.lm.model_2 <- lm(mayo.pred.log2.lr ~ mayo.fc.log2.lr)

mayo.log2_group.1 <- data.frame(obs = mayo.fc.log2.lr, X1 = mayo.pred.log2.lr)
mayo_group.1 <- data.frame(d0=mayo.d0.log2.lr, fc=mayo.fc.log2.lr, X1 =mayo.pred.log2.lr)

### --- Day-0 group2 modeling ---- ###
# Baylor group 2
cutoff.low <- clust_cutpoints[1]
cutoff.high <- clust_cutpoints[2]
bay.d0.med.idx <- which(cutoff.low < bay.d0.log2 & bay.d0.log2 <= cutoff.high)
bay.d0.med <- bay.d0[bay.d0.med.idx]
bay.fc.med <- bay.fc[bay.d0.med.idx]
bay.d0.log2.med <- bay.d0.log2[bay.d0.med.idx]
bay.fc.log2.med <- bay.fc.log2[bay.d0.med.idx]
bay.fc.log2.resid.med <- bay.fc.log2.resid[bay.d0.med.idx]

# Fit data with glmnet
bay.glmnet.fit2 <- cv.glmnet(bay.pair.tg[bay.d0.med.idx, ], bay.fc.log2.resid.med, alpha = 0)
bay.lambda <- bay.glmnet.fit2$lambda.min
# Feature selection
coef <- predict(bay.glmnet.fit2, s = bay.lambda, type = "coefficients")
selected_features <- names(which(abs(coef[-1,1]) > 0))
selected_features <- grep("Intercept", selected_features, invert = TRUE, value = TRUE)

# Predict on the Baylor
bay.pred.log2.resid.med <- predict(bay.glmnet.fit2, s = bay.lambda, newx = bay.pair.tg[bay.d0.med.idx, ])

# Predicted vs observed-residuals scale
bay.lm.model_1 <- lm(bay.pred.log2.resid.med ~ bay.fc.log2.resid.med)
bay.med.r2 <- summary(bay.lm.model_1)$r.squared

# Predicted vs observed-log2 scale
bay.pred.log2.med  <- bay.pred.log2.resid.med + (a + b*bay.d0.log2.med) # Y <- residuals + Y.hat
bay.lm.model_2 <- lm(bay.pred.log2.med ~ bay.fc.log2.med)

bay.log2_group.2 <- data.frame(obs = bay.fc.log2.med, X1 = bay.pred.log2.med)
bay_group.2 <- data.frame(d0=bay.d0.log2.med, fc=bay.fc.log2.med, X1 =bay.pred.log2.med)

# Emory group2
emory.d0.med.idx <- which(cutoff.low < emory.d0.log2 & emory.d0.log2 <= cutoff.high)
emory.d0.med <- emory.d0[emory.d0.med.idx]
emory.fc.med <- emory.fc[emory.d0.med.idx]
emory.d0.log2.med <- emory.d0.log2[emory.d0.med.idx]
emory.fc.log2.med <- emory.fc.log2[emory.d0.med.idx]
emory.fc.log2.resid.med <- emory.fc.log2.resid[emory.d0.med.idx]

# Predict on the Emory
emory.pred.log2.resid.med <- predict(bay.glmnet.fit2, s = bay.lambda, newx = emory.pair.tg[emory.d0.med.idx, ])

# Predicted vs observed-residuals scale
emory.lm.model_1 <- lm(emory.pred.log2.resid.med ~ emory.fc.log2.resid.med)
emory.med.r2 <- summary(emory.lm.model_1)$r.squared

# Predicted vs observed-log2 scale
emory.pred.log2.med  <- emory.pred.log2.resid.med + (a + b*emory.d0.log2.med) # Y <- residuals + Y.hat
emory.lm.model_2 <- lm(emory.pred.log2.med ~ emory.fc.log2.med)

emory.log2_group.2 <- data.frame(obs = emory.fc.log2.med, X1 = emory.pred.log2.med)
emory_group.2 <- data.frame(d0=emory.d0.log2.med, fc=emory.fc.log2.med, X1 =emory.pred.log2.med)

# Mayo group2
mayo.d0.med.idx <- which(cutoff.low < mayo.d0.log2 & mayo.d0.log2 <= cutoff.high)
mayo.d0.med <- mayo.d0[mayo.d0.med.idx]
mayo.fc.med <- mayo.fc[mayo.d0.med.idx]
mayo.d0.log2.med <- mayo.d0.log2[mayo.d0.med.idx]
mayo.fc.log2.med <- mayo.fc.log2[mayo.d0.med.idx]
mayo.fc.log2.resid.med <- mayo.fc.log2.resid[mayo.d0.med.idx]

# Predict on the mayo
mayo.pred.log2.resid.med <- predict(bay.glmnet.fit2, s = bay.lambda, newx = mayo.pair.tg[mayo.d0.med.idx, ])

# Predicted vs observed-residuals scale
mayo.lm.model_1 <- lm(mayo.pred.log2.resid.med ~ mayo.fc.log2.resid.med)
mayo.med.r2 <- summary(mayo.lm.model_1)$r.squared

# Predicted vs observed-log2 scale
mayo.pred.log2.med  <- mayo.pred.log2.resid.med + (a + b*mayo.d0.log2.med) # Y <- residuals + Y.hat
mayo.lm.model_2 <- lm(mayo.pred.log2.med ~ mayo.fc.log2.med)

mayo.log2_group.2 <- data.frame(obs=mayo.fc.log2.med, X1 = mayo.pred.log2.med)
mayo_group.2 <- data.frame(d0=mayo.d0.log2.med, fc=mayo.fc.log2.med, X1 =mayo.pred.log2.med)

### --- Day-0 group3 modeling ---- ###
# Baylor group 3
bay.d0.hi.idx <- which(clust_cutpoints[2] < bay.d0.log2)
bay.d0.hi <- bay.d0[bay.d0.hi.idx]
bay.fc.hi <- bay.fc[bay.d0.hi.idx]
bay.d0.log2.hi <- bay.d0.log2[bay.d0.hi.idx]
bay.fc.log2.hi <- bay.fc.log2[bay.d0.hi.idx]
bay.fc.log2.resid.hi <- bay.fc.log2.resid[bay.d0.hi.idx]

# Predicted vs observed-log2 scale
bay.pred.log2.hi <- predict(bay.logfit, newdata=data.frame(d0=bay.d0.log2))[bay.d0.hi.idx] # Baylor day-0 linear fit
bay.lm.model_2 <- lm(bay.pred.log2.hi ~ bay.fc.log2.hi)

bay.log2_group.3 <- data.frame(obs = bay.fc.log2.hi, X1 = bay.pred.log2.hi)
bay_group.3 <- data.frame(d0=bay.d0.log2.hi, fc=bay.fc.log2.hi, X1 =bay.pred.log2.hi)


# Emory group 3
emory.d0.hi.idx <- which(clust_cutpoints[2] < emory.d0.log2)
emory.d0.hi <- emory.d0[emory.d0.hi.idx]
emory.fc.hi <- emory.fc[emory.d0.hi.idx]
emory.d0.log2.hi <- emory.d0.log2[emory.d0.hi.idx]
emory.fc.log2.hi <- emory.fc.log2[emory.d0.hi.idx]
emory.fc.log2.resid.hi <- emory.fc.log2.resid[emory.d0.hi.idx]

# Predicted vs observed-log2 scale
emory.pred.log2.hi  <- predict(bay.logfit, newdata=data.frame(d0=emory.d0.log2))[emory.d0.hi.idx] # Baylor day-0 linear fit
emory.lm.model_2 <- lm(emory.pred.log2.hi ~ emory.fc.log2.hi)

emory.log2_group.3 <- data.frame(obs = emory.fc.log2.hi, X1 = emory.pred.log2.hi)
emory_group.3 <- data.frame(d0=emory.d0.log2.hi, fc=emory.fc.log2.hi, X1 =emory.pred.log2.hi)

# Mayo group 3
mayo.d0.hi.idx <- which(clust_cutpoints[2] < mayo.d0.log2)
mayo.d0.hi <- mayo.d0[mayo.d0.hi.idx]
mayo.fc.hi <- mayo.fc[mayo.d0.hi.idx]
mayo.d0.log2.hi <- mayo.d0.log2[mayo.d0.hi.idx]
mayo.fc.log2.hi <- mayo.fc.log2[mayo.d0.hi.idx]
mayo.fc.log2.resid.hi <- mayo.fc.log2.resid[mayo.d0.hi.idx]

# Predicted vs observed-log2 scale
mayo.pred.log2.hi <- predict(bay.logfit, newdata=data.frame(d0=mayo.d0.log2))[mayo.d0.hi.idx] # Baylor day-0 linear fit
mayo.lm.model_2 <- lm(mayo.pred.log2.hi ~ mayo.fc.log2.hi)

mayo.log2_group.3 <- data.frame(obs = mayo.fc.log2.hi, X1 = mayo.pred.log2.hi)
mayo_group.3 <- data.frame(d0=mayo.d0.log2.hi, fc=mayo.fc.log2.hi, X1 =mayo.pred.log2.hi)


#### ----- PEICEWISE log2 scale ----- ####
bay.log2.group <- rbind(bay.log2_group.1, bay.log2_group.2, bay.log2_group.3)
bay.group.plot <- rbind(bay_group.1, bay_group.2, bay_group.3)

bay.legend.fit <- "Baylor Model"
bay.legend.dat1 <- "Baylor Data"

bay.override.shape <- c(1, 2)
bay.override.color <- c("black","red")

# bay.rmsd <- sqrt(mean((bay.log2.group$X1-bay.log2.group$obs)^2))
bay.r2 <- summary(lm(bay.log2.group$X1~bay.log2.group$obs))$r.squared
lb1 <- paste("R^2 ==", round(bay.r2,digits=2))

g1 <- ggplot(bay.group.plot) +
  geom_point(aes(x = d0, y = fc, color=bay.legend.dat1, shape = "Baylor Data"), size = 2.5) +
  geom_point(aes(x = d0, y = X1, color=bay.legend.fit, shape = "Baylor Model"), size = 2.5) +
  geom_vline(xintercept = clust_cutpoints[1], colour="blue", linetype = "longdash") +
  geom_vline(xintercept = clust_cutpoints[2], colour="blue", linetype = "longdash") +
  xlab("log2(Baseline)") +
  ylab("log2(Fold-change)") +
  ggtitle("Train on Baylor (baseline genes)") + 
  annotate("text", x=5, y=4.3, hjust=0, label=lb1, parse=TRUE,size=6) +
  theme(axis.text.x = element_text(size = 20),
        axis.title.x = element_text(size=20),
        axis.text.y = element_text(size = 20),
        axis.title.y = element_text(size = 20),
        panel.background = element_rect(fill = 'white', colour = 'black'), #element_blank(),
        panel.grid.major = element_line(colour = "gray"),
        panel.grid.minor = element_line(colour = "gray"),
        axis.text=element_text(size=20),
        plot.title = element_text(size = 20, face = "bold"),
        legend.text = element_text(size = 16),
        legend.position = c(.78,.8)) +
  scale_shape_manual(name  ="HAI",
                     values=c("Baylor Data"=1,"Baylor Model"=2)) +
  guides(colour = guide_legend(override.aes = list(shape = bay.override.shape,  
                                                   color = bay.override.color),  reverse=TRUE,  title="HAI")) +
  scale_colour_manual(name  ="HAI", values = bay.override.color,
                      breaks=c("Baylor Model", "Baylor Data"),
                      labels=c("Baylor Model", "Baylor Data"))



# Emory group plot
emory.log2.group <- rbind(emory.log2_group.1, emory.log2_group.2, emory.log2_group.3)
emory.group.plot <- rbind(emory_group.1, emory_group.2, emory_group.3)

# Function for cbind data frames with different rows
cbind.na<-function(df1, df2){
  
  #Collect all unique rownames
  total.rownames<-union(x = rownames(x = df1),y = rownames(x=df2))
  
  #Create a new dataframe with rownames
  df<-data.frame(row.names = total.rownames)
  
  #Get absent rownames for both of the dataframe
  absent.names.1<-setdiff(x = rownames(df1),y = rownames(df))
  absent.names.2<-setdiff(x = rownames(df2),y = rownames(df))
  
  #Fill absents with NAs
  df1.fixed<-data.frame(row.names = absent.names.1,matrix(data = NA,nrow = length(absent.names.1),ncol=ncol(df1)))
  colnames(df1.fixed)<-colnames(df1)
  df1<-rbind(df1,df1.fixed)
  
  df2.fixed<-data.frame(row.names = absent.names.2,matrix(data = NA,nrow = length(absent.names.2),ncol=ncol(df2)))
  colnames(df2.fixed)<-colnames(df2)
  df2<-rbind(df2,df2.fixed)
  
  #Finally cbind into new dataframe
  df<-cbind(df,df1[rownames(df),],df2[rownames(df),])
  return(df)
  
}
emory_2007.df <- data.frame(d01=emory.d0.log2[1:28], fc1=emory.fc.log2[1:28])
emory_2009.df <- data.frame(d02=emory.d0.log2[29:86], fc2=emory.fc.log2[29:86])
emory.prebind.df <- cbind.na(emory_2007.df, emory_2009.df)
rownames(emory.group.plot) <- NULL
emory.group.plot_2 <- cbind.na(emory.prebind.df, emory.group.plot)

emory.legend.fit <- "Baylor Model"
emory.legend.dat1 <- "Emory Data 2007-2009"
emory.legend.dat2 <- "Emory Data 2009-2011"

emory.override.shape <- c(2, 4, 1)
emory.override.color <- c("red", "purple", "black")

# emory.rmsd <- rmse(emory.log2.group$X1, emory.log2.group$obs)
emory.r2 <- summary(lm(emory.log2.group$X1~emory.log2.group$obs))$r.squared
lb1 <- paste("R^2 ==", round(emory.r2,digits=2))

g2 <- ggplot(emory.group.plot_2) +
  geom_point(aes(x = d01, y = fc1, color=emory.legend.dat1, shape = "Emory Data 2007-2009"), size = 2.5) +
  geom_point(aes(x = d02, y = fc2, color=emory.legend.dat2, shape = "Emory Data 2009-2011"), size = 2.5) +
  geom_point(aes(x = d0, y = X1, color=emory.legend.fit, shape = "Baylor Model"), size = 2.5) +
  geom_vline(xintercept = clust_cutpoints[1], colour="blue", linetype = "longdash") +
  geom_vline(xintercept = clust_cutpoints[2], colour="blue", linetype = "longdash") +
  xlab("log2(Baseline)") +
  ylab("log2(Fold-change)") +
  ggtitle("Prediction on Emory (baseline genes)") + 
  annotate("text", x=6.3, y=6.0, hjust=0, label=lb1, parse=TRUE,size=6) +
  theme(axis.text.x = element_text(size = 20),
        axis.title.x = element_text(size=20),
        axis.text.y = element_text(size = 20),
        axis.title.y = element_text(size = 20),
        panel.background = element_rect(fill = 'white', colour = 'black'), #element_blank(),
        panel.grid.major = element_line(colour = "gray"),
        panel.grid.minor = element_line(colour = "gray"),
        axis.text=element_text(size=20),
        plot.title = element_text(size = 20, face = "bold"),
        legend.text = element_text(size = 16),
        legend.position = c(.82,.85)) +
  scale_shape_manual(name  ="HAI",
                     values=c("Emory Data 2007-2009"=4,"Emory Data 2009-2011"=1, "Baylor Model"=2)) +
  guides(colour = guide_legend(override.aes = list(shape = emory.override.shape,  
                                                   color=emory.override.color), reverse=F,  title="HAI")) +
  scale_colour_manual(name  ="HAI",values=emory.override.color,
                      breaks=c("Baylor Model", "Emory Data 2007-2009", "Emory Data 2009-2011"),
                      labels=c("Baylor Model", "Emory Data 2007-2009", "Emory Data 2009-2011"))


# Mayo group plot
mayo.log2.group <- rbind(mayo.log2_group.1, mayo.log2_group.2, mayo.log2_group.3)
mayo.group.plot <- rbind(mayo_group.1, mayo_group.2, mayo_group.3)

legend.fit <- "Baylor Model"
legend.dat1 <- "Mayo Data"

override.shape <- c(2, 1)
override.color <- c("red", "black")

mayo.r2 <- summary(lm(mayo.log2.group$X1~mayo.log2.group$obs))$r.squared
lb1 <- paste("R^2 ==", round(mayo.r2,digits=2))

g3 <- ggplot(mayo.group.plot) +
  geom_point(aes(x = d0, y = fc, color=legend.dat1, shape = "Mayo Data"), size = 2.5) +
  geom_point(aes(x = d0, y = X1, color=legend.fit, shape = "Baylor Model"), size = 2.5) +
  geom_vline(xintercept = clust_cutpoints[1], colour="blue", linetype = "longdash") +
  geom_vline(xintercept = clust_cutpoints[2], colour="blue", linetype = "longdash") +
  xlab("log2(Baseline)") +
  ylab("log2(Fold-change)") +
  ggtitle("Prediction on Mayo (baseline genes)") + 
  annotate("text", x=8.3, y=3.5, hjust=0, label=lb1, parse=TRUE,size=6) +
  theme(axis.text.x = element_text(size = 20),
        axis.title.x = element_text(size=20),
        axis.text.y = element_text(size = 20),
        axis.title.y = element_text(size = 20),
        panel.background = element_rect(fill = 'white', colour = 'black'), #element_blank(),
        panel.grid.major = element_line(colour = "gray"),
        panel.grid.minor = element_line(colour = "gray"),
        axis.text=element_text(size=20),
        plot.title = element_text(size = 20, face = "bold"),
        legend.text = element_text(size = 16),
        legend.position = c(.8,.85)) +
  scale_shape_manual(name  ="HAI",values=c("Mayo Data"=1,"Baylor Model"=2)) +
  guides(colour = guide_legend(override.aes = list(shape = override.shape,  
                                                   color=override.color),  reverse=F,  title="HAI")) +
  scale_colour_manual(name  ="HAI", values=override.color,
                      breaks=c("Baylor Model", "Mayo Data"),
                      labels=c("Baylor Model", "Mayo Data"))


# barplot of low/med/high subjects - log2 scale
barplot_data <- data.frame(Data = c("Baylor", "Emory", "Mayo"),
                           Low=c(length(bay_group.1$d0), length(emory_group.1$d0), length(mayo_group.1$d0)), 
                           Medium=c(length(bay_group.2$d0), length(emory_group.2$d0), length(mayo_group.2$d0)), 
                           High=c(length(bay_group.3$d0), length(emory_group.3$d0), length(mayo_group.3$d0)))

# melt the data frame for plotting
barplot_data.m <- melt(barplot_data, id.vars="Data", variable_name = "Group")

g4 <- ggplot(barplot_data.m, aes(Group, value)) +  geom_bar(aes(fill = Data), position = "dodge", stat="identity") +
  ggtitle("Baseline HAI Groups") +
  ylab("Subjects") +
  theme(axis.text.x = element_text(size = 20),
        axis.title.x = element_text(size=20),
        axis.text.y = element_text(size = 20),
        axis.title.y = element_text(size = 20),
        axis.text=element_text(size=20),
        plot.title = element_text(size = 20, face = "bold"))

grid.arrange(g1, g2, g3, g4, ncol = 2, nrow = 2)

