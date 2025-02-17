Main.AHSA<-function(DATA,Y,k.cur,k.comp,w,IterMax,met.cur,met.comp,met.class,met.val){
  ###################################################################################################
  # AHSA: Algoritmo H�brido para la Selecci�n de Atributos
  # 
  # ENTRADAS
  # DATA    : matriz de atributos 
  # Y       : Vector de clases
  # VarName : Nombre de la variables 
  # k.cur   : cantidad de columnas a seleccionar:  valores {3,4,5,6,...,10}
  # k.comp  : cantidad de componentes PLS o PCA usadas para clasificar: valores (k.comp <= k.cur)
  # w       : pesos para ponderar la frecuencia y el error en el factor importancia {0.5}
  # IterMax : N�mero m�ximo de iteraciones {100,200,300,400}
  # met.cur : m�todo usado en CUR para las seleccionar columnas: {1,2} preferible 2
  # met     : metodos para obtener componentes  si met = 1 => pls  si met = 2 => pca
  # SALIDAS
  # BestVar    : Vector con los nombres de las mejors variables
  # NumBestVar : Vector con ID de las mejores variables 
  # EBCV       : Raz�n de clasificaci�n correcta 
  # HH         : Ranking (matriz)
  ###################################################################################################
  library("rCUR")
  library("boot")
  library("plsgenomics")
  library("class")
  #Inicializaci�n# 
  ptm <- proc.time()
  m<-dim(DATA)[1]                                        # cantidad de observaciones
  n<-dim(DATA)[2]                                        # cantidad de atributos 
  VarName<-colnames(DATA)                                # nombre de los atributos
  X<-as.matrix(DATA)                                     # transformaci�n de la variable DATA  a  X tipo de dato matriz                                                     # Descomposici�n del valor singular
  XScale <- scale(X, center = TRUE, scale = TRUE)        # escalar y centrar la  matriz de datos
  Xsvd <- svd(XScale)                                    # descomposici�n del valor singular de la matriz de datos      
  #Iniciaizaci�n de variables auxiliares
  Hfvar<-rep(0,n)                                        # almacena la frecuencia  hist�rica de selecci�n  de cada variable (Ratio) 
  HEbcv<-rep(0,n)                                        # almacena el errorBCV hist�rico de los modelos en a ha estado presente una variable 
  HIvar<-rep(0,n)                                        # almacena la importancia de la variable dentro de los modelos en los cuales ha estado presente
  Hfimp<-rep(0,n)                                        # almacena el factor de permanencia para el filtrado
  Iter<-1; Stop0<-0; Stop1<-0;Stop2<-0                   # condiciones de parada (inicilizaci�n)
  #Iteraci�n Iter=0
  SVar<-SvarCUR(X,Xsvd,k.cur,met.cur)                                             # atributos seleccionados mediante CUR                             
  AuxClass<-Class.CV.LOO.B(XScale,Y,SVar,k.cur,k.comp,met.comp,met.class,met.val) # Evaluaci�n de los atributos seleccionados          
  NumBestVar<-SVar
  VarSelect<-SVar                                                                 # seleci�n inicial de variables                                      
  for(i in 1:length(VarSelect)){
    j<-VarSelect[i]
    Hfvar[j]<-Hfvar[j]+1                                 # c�culo de la frecuencia de aparici�n del atributo
    HEbcv[j]<-HEbcv[j]+AuxClass$Error                                                 
    HIvar[j]<-(HIvar[j]+AuxClass$VIP[i])                 # c�lculo del factor de importancia del ratio de acuerdo al modelo  
    Hfimp[j]<- (w*((Hfvar[j]/IterMax)+(HEbcv[j])/(Hfvar[j]))+(1-w)*(HIvar[j]/Hfvar[j])) # c�lculo del factor de permanencia (FALTA ->  w3*HIvar[j])
  }
  BestVar <-VarName[SVar]                               # mejores atributos hasta el momento                                                  # mejores Coeficientes
  BestFitnessBCV<-AuxClass$Error                        # Mejor Error
  while(Stop0<1){
    Iter<-Iter+1    
    SVar<-SvarCUR(X,Xsvd,k.cur,met.cur)                                                         # atributos seleccionados mediante CUR 
    AuxClass<-Class.CV.LOO.B(XScale,Y,SVar,k.cur,k.comp,met.comp,met.class,met.val)             # Evaluaci�n de los atributos seleccionados 
    if(AuxClass$Error>=BestFitnessBCV){                                                         # actualizar el  mejor modelo  hasta el momento
      BestVar<-VarName[SVar] 
      NumBestVar<-SVar
      BestFitnessBCV<-AuxClass$Error
    } # if (actualizar mejor modelo) 
    VarSelect<-SVar
    for(i in 1:length(VarSelect)){
      j<-VarSelect[i]
      Hfvar[j]<-Hfvar[j]+1                                                      # c�culo de la frecuencia de aparici�n del atributo
      HEbcv[j]<-HEbcv[j]+AuxClass$Error                                                                      
      HIvar[j]<-(HIvar[j]+AuxClass$VIP[i])
      Hfimp[j]<-(w*((Hfvar[j])/IterMax)+(1-w)*((HEbcv[j])/(Hfvar[j])+(HIvar[j]/Hfvar[j]))) # c�lculo del factor de permanencia (FALTA ->  w3*HIvar[j])
    }
    #print(Iter)
    #print(BestFitnessBCV)
    # condici�n de parada
    if(Iter==IterMax){
      Stop1<-1
    } # Stop1
    if(BestFitnessBCV>0.99){
      Stop2<-1
    } # Stop2
    Stop0<-Stop1+Stop2
  } # while
  HH<-matrix(0,nrow=n,ncol=4)
  HH[,1]<-Hfvar
    for (y in 1:n){
    if(Hfvar[y]!=0){
      HH[y,3]<-HIvar[y]/Hfvar[y]
      HH[y,2]<-HEbcv[y]/Hfvar[y]
      HH[y,4]<-Hfimp[y]
    }
  }
  VarRank<-sort.int(Hfimp,partial = NULL, na.last = NA, decreasing = TRUE, method = c("shell", "quick"), index.return = TRUE)$ix
  VarName<-VarName[VarRank]
  HH[,1]<-HH[VarRank,1]
  HH[,2]<-HH[VarRank,2]
  HH[,3]<-HH[VarRank,3]
  HH[,4]<-HH[VarRank,4]
  rownames(HH)<-VarName
  time<- (ptm - proc.time())
  colnames(HH)<-c("Frec","M.EBCV","VIP","Rank")
  return(list(BestVar=BestVar,NumBestVar=NumBestVar,EBCV=BestFitnessBCV,HH=HH,time=time))
 
} # function
#----------------------------------------------------------------------------------------------------------------
SvarCUR<-function(X,Xsvd,k.cur,met.cur){
  ######################################################################################################################
  # SvarCUR: Selecci�n de atributos mediante la descomposici�n CUR 
  # Entradas
  # X      : Matriz de datos (Emp X Ratios)
  # Xsvd   : Descomposici�n del valor singular de la matriz de datos
  # k.cur  : Cantidad de atributos(columnas de X) a seleccionar en CUR
  # met.cur: m�todo para la seleccion de columnas usado en algoritmo ColumnSelect (CUR)
  # Salidas
  # SVar: Atributos selecciondos mediante la descompocisi�n CUR
  #####################################################################################################################
  Stop<-0                                     # Condici�n de parada while (CUR)                            
  # m�todo de selecci�n columnas en CUR
  if(met.cur==1){ 
    method<-"random"
  } # Met 1
  if(met.cur==2){
    method<-"exact.num.random" 
  } 
  if(met.cur==3){
    method<-"top.scores" 
  } 
  if(met.cur==4){
    method<-"ortho.top.scores" 
  } 
  if(met.cur==5){
    method<-"highest.ranks" 
  } 
  # descomposici�n matricial CUR 
  while(Stop==0){
    CURResults <- CUR(X, c= k.cur, r= dim(X)[1], k = k.cur, sv = Xsvd ,method,alpha=1, weighted = FALSE, beta = 4,matrix.return = TRUE) 
    SVarCUR <- CURResults@C.index             # Atributos seleccionados                  
    if(length(SVarCUR)>1){
      Stop<-1
    }
  }
  #Salida
  return(SVar=SVarCUR)
}

#----------------------------------------------------------------------------------------------------------------
Class.CV.LOO.B <-function(Dmatriz,Y,SVar,k.cur,k.comp,met.comp,met.class,met.val)
  {
  # Entrada
  # X: Subconjunto de la matriz  de datos seleccionado mediante la descomposici�n CUR
  # Y: variable dependiente (contiene las clases)
 
    # componentes pls
    if(met.comp=="pls"){
      X<-Dmatriz[,SVar]
      nc<-length(SVar)
      pls.out <- pls.regression(Xtrain =X, Ytrain = Y, ncomp = k.cur)
      T<- pls.out$T
      W <- pls.out$R
      C<-T[,1:k.comp]
      YX <- data.frame(Y,C)
      RdYTm<-rep(0,nc)
      RdYTh<-rep(0,nc)
      VIP<-rep(0,nc)
      for (i in 1:nc){
        for(j in 1:nc){
          RdYTm[j]<-(cor(Y,T[,j]))^2
          RdYTh[j]<-RdYTm[j]*(W[i,j])^2
        }
        VIP[i]<-sqrt((nc/sum(RdYTm))*(sum(RdYTh)))
      }
      VIP<-VIP/sqrt(sum(VIP^2))
    }
    # componentes pca
    if(met.comp=="pca"){
      X<-Dmatriz[,SVarCUR]
      pca.out <- princomp(XX)
      COMP<- pca.out$scores
      C<-COMP[,1:k.comp]
      YX <- data.frame(Y,C)
      VIP<-rep(0,nc)
    }
    # selecci�n cur
    if(met.comp=="nc"){
      C<-Dmatriz[,SVarCUR]
      nc<-length(SVarCUR)
      YX <- data.frame(Y,X)
      VIP<-rep(0,nc)
    }
 # Clasificador lda
 if(met.class=="lda"){ 
   # M�todo validaci�n cruzada
   if(met.val=="cv"){
     Class<-pls.lda(Xtrain=C,Ytrain=Y, Xtest=NULL, ncomp=k.comp, nruncv=10, alpha=2/3, priors=NULL)
     ClassTest<-table(Class$predclass,Y)
     Class<-table(Y)
     aux1<-diag(ClassTest)/Class
     aux2<-mean(aux1)
     Error<-signif(aux2,4)  
     }# met.val==1
   # M�todo Leave one out
   if(met.val=="loo"){
       Classlda<-lda(x=C,grouping=Y,CV = TRUE)
       Class<-table(Y)
       ClassTest<-table(Classlda$class,Y)
       aux1<-diag(ClassTest)/Class
       aux2<-mean(aux1)
       Error<-signif(aux2, 4)  
   }#met.val==2
  # M�todo Bootstrap
 if(met.val=="bt"){
   Accuracy.rate <- function(formula,data,indices){
     Modlda<-lda(formula,data,CV = TRUE)
     Class<-table(data$Y)
     ClassTest<-table(Modlda$class,data$Y)
     aux1<-diag(ClassTest)/Class
     aux2<-mean(aux1)
     error<-signif(aux2, 4)  
     return(error)
   }
   boot.out <- boot(data = YX, statistic = Accuracy.rate, R = 200, formula = Y~X,parallel="multicore",ncpus=2)
   Error <- mean(boot.out$t)
 }#met.val==3
 } # met.class=="lda"
 # Clasificador 
 if(met.class=="knn"){ 
   # M�todo validadci�n cruzada
   if(met.val==1){
     Classknn<-knn.cv(train=C,cl=Y, k = 3, l = 0, prob = FALSE, use.all = TRUE)
     Class<-table(Y)
     ClassTest<-table(Classknn,Y)
     aux1<-diag(ClassTest)/Class
     aux2<-mean(aux1)
     Error<-signif(aux2, 4)      
   }
   # M�todo bootstrap
   if(met.val==2){
     Accuracy.rate <- function(formula, data,indices){
       Classknn<-knn(train=data[,2:dim(data)[2]],test=data[,2:dim(data)[2]],cl=as.factor(data$Y), k = 3, l = 0, prob = FALSE, use.all = TRUE)
       Class<-table(data$Y)
       ClassTest<-table(Classknn,data$Y)
       aux1<-diag(ClassTest)/Class
       aux2<-mean(aux1)
       error<-signif(aux2, 4)  
       return(error)
     }
     boot.out <- boot(data = YX, statistic = Accuracy.rate , R =200,sim="ordinary", formula = Y~X,parallel="multicore",ncpus=2)
     Error <- mean(boot.out$t)
   }
} #knn.
     return(list(Error=Error,VIP=VIP))
     # Salidas
     # Fitness: precisi�n del modelo descriminate
     # Coef   : modelo descriminate 
}

#----------------------------------------------------------------------------------------------------------------
