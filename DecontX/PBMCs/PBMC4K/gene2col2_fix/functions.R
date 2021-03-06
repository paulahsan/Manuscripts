
# >>>> for loading sorted PBMCs data

# Functions to adjust sorted label according to celda clustering result
adjust.label = function(celda.cluster, sorted.label ) {
	  tb = table( sorted.label, celda.cluster )
  celdaZ.correspondingLabel = apply( tb, 2, FUN=function(x) rownames(tb)[which.max(x)] )
	  celdaZ.correspondingLabelU = unname(celdaZ.correspondingLabel)
	  for (i in 1:length(unique(celda.cluster)) ) {
			    sorted.label[ celda.cluster == i ] = celdaZ.correspondingLabelU [i ]
		  }
		  return( sorted.label )
}


# Collapse sorted cell labels
convert.sortLabel = function( ori.label, new.label     )  {
	        z = ori.label
        for (label in new.label) {
					                if( label != "CD34_cells" ) {
														      z[ grep( paste0( label, "$") , ori.label , perl=TRUE ) ] = label
				          }
				  }
				        return( z)  }
# <<<<


# >>>>>  functions for plots

## Set colors
RNGkind(sample.kind = "Rounding")
set.seed( 824) 
color30 = celda::distinctColors(30)[ sample(1:30 , size = 30 ) ]  

## Function to match one set of cell labels to another set of cell labels
## @mat, a table from table(cluster-set1, cluster-set2)  
match.label = function( mat ) { 
	nRow = nrow( mat)
	nCol = ncol( mat )
	rownames( mat ) = as.character(1: nRow)
	colnames( mat ) = as.character(1: nCol)
	for ( i in 1:nRow)  {
		index =  which.max( mat[i, ] )
		if ( index != i )  { 
			col.names = colnames( mat) [ c( index, i )  ] 
			mat[ , c( i, index) ] = mat[, c(index, i) ]  
			colnames( mat ) [ c(i, index) ]  = col.names 
		}
	}
	return( mat )
}



## Function to recode cell labels for celda object, 
## dependent on function match.label
reorderZ = function( ori.celda, decon.celda ) {
	tb.z = table( ori.celda@clusters$z, decon.celda@clusters$z ) 
	reorder.tb.z = match.label( tb.z) 
	K = decon.celda@params$K 
	return(  recodeClusterZ( decon.celda, from = as.integer( colnames( reorder.tb.z) ) , to = 1: K )  ) 
} 

## Function to collapse multiple cell clusters (z) to cell type  
label.AB= function( z, A.cluster = NULL, B.cluster = NULL, A.name, B.name ) {
	z.AB = z 
	if ( !is.null(A.cluster) ) {
	    z.AB[ z %in% A.cluster ] = A.name
	}
	if ( !is.null(B.cluster) ) {
	    z.AB[ z %in% B.cluster ] = B.name
	}	
	z.AB[ ! z.AB  %in% c( A.name, B.name ) ] = "others"
	return(z.AB) 
}

## Function to calculate cluster-specific gene expression 
## taking output from label.AB
cluster.gene = function(counts, z.AB) {

	counts = celda::normalizeCounts( counts, "cpm")

        z.AB.int = as.factor(z.AB)
        levels(z.AB.int) = 1:length(levels(z.AB.int))  #
        m.by.cellcluster = as.integer(table(z.AB))

        # average expression of each gene
	gene.mean.cellcluster = rowsum( t(counts), group = z.AB.int, reorder=TRUE)
        gene.mean.cellcluster = t( gene.mean.cellcluster / m.by.cellcluster)
        colnames(gene.mean.cellcluster) = levels(as.factor(z.AB))
        
	# average log2-expression of each gene
	log.counts = log2( counts + 1) 
	log2.gene.mean.cellcluster = rowsum( t(log.counts), group = z.AB.int, reorder =TRUE)
        log2.gene.mean.cellcluster = t( log2.gene.mean.cellcluster / m.by.cellcluster)
        colnames(log2.gene.mean.cellcluster) = paste0("log2.", levels(as.factor(z.AB)))

        ##df.gene = data.frame(gene.mean.cellcluster, gene.proportion.cellcluster, log2.gene.mean.cellcluster )
	df = data.frame(gene.mean.cellcluster, log2.gene.mean.cellcluster) 
        df$gene = rownames(counts)
	df$gene = gsub(".*_", "", df$gene)
        return(df)
}


rbind.geneExp = function( geneExp.ori, geneExp.pos, geneExp.immune) { 
    geneExp.ori$datatype = "Original 4K PBMC\n(profiled in the same channel)"
    geneExp.pos$datatype = "Decontaminated 4K PBMC\n(profiled in the same channel)"
    geneExp.immune$datatype = "Sorted PBMCs\n(profiledin different channels)" 
    df.rbind = rbind( geneExp.ori, geneExp.pos , geneExp.immune ) 
    df.rbind$datatype_f = factor( df.rbind$datatype, levels = c("Sorted PBMCs\n(profiledin different channels)",  
								"Original 4K PBMC\n(profiled in the same channel)", 
								"Decontaminated 4K PBMC\n(profiled in the same channel)") ) 
    return( df.rbind) 
}


##  Scatter plot of gene expressions from 2 subpopulations.
plot.gene.exp = function( df.AB.gene,  x, y,  Genes, colors,  size=0.8, hjust=4, vjust=1, repel_text.size=3  ) {
	df.AB.gene$repel_label = ""
	df.AB.gene$repel_label[ df.AB.gene$gene %in% Genes ] = df.AB.gene$gene[df.AB.gene$gene %in% Genes ] 
	colnames( df.AB.gene)[ which(  colnames(df.AB.gene) == x )   ]  = "CellType_1" 
	colnames( df.AB.gene)[ which(  colnames(df.AB.gene) == y )   ]  = "CellType_2"
	p = ggplot( df.AB.gene, aes( x = CellType_1, y = CellType_2, color=repel_label, label=repel_label  ) ) + theme_minimal() + 
		geom_point(size=size,  colour = 'grey69'  ) +  
		geom_point(data=df.AB.gene[ df.AB.gene$gene %in% Genes,   ], 
			   aes( x = CellType_1, y = CellType_2 , color=gene) , size = 2 * size ) + 
		geom_text_repel(  hjust=hjust, vjust=vjust, size=repel_text.size ) +
		scale_color_manual( values= colors) + 
		            theme(panel.background=element_rect(fill="white", color="grey"),
	                          panel.grid = element_line("grey"), legend.position="none",
	                          legend.key=element_rect(fill="white", color="white"),
   	                          panel.grid.minor = element_blank(),
	                          text=element_text(size=10 ),
	       	                  axis.text.x = element_text(size=8),
		                  axis.text.y=element_text(size=8),
		                  legend.key.size = grid::unit(8, "mm"),
			          legend.text = element_text(size=8) , 
			          strip.text.x = element_text(size = 10)  )
	return( p ) 

}



## Function to extract color from a ggplot 
exc.color = function( plt.ggplot, z )  { 
	g.build = ggplot_build( plt.ggplot) 
	color = g.build$data[[1]]$colour 
	tb = table( z, color) 
	color.K = apply( tb, 1, FUN=function(v) { colnames(tb) [ which.max( v )  ]  }  ) 
        return( color.K ) 
}

## Function to calculate silhouette width 
s.width = function( counts, z ) { 
    counts = normalizeCounts( counts, "cpm" ) 
    distance = dist( t(counts) , method = "euclidean", diag =FALSE, upper=FALSE, p=2) 
    s.width = cluster::silhouette( x = z, dist = distance )
    return( s.width) 

}

## Function to plot silhouette width (boxplot) for the difference of original data and decontamintaed data
silhouetteDiff.plot = function( silhouette.ori, silhouette.dec, K, color, exK = NULL ) { 
    sil.ori = summary( silhouette.ori) 
    sil.dec = summary( silhouette.dec) 
    df = data.frame(diff =  - sil.ori$clus.avg.widths + sil.dec$clus.avg.widths, 
		    Cluster = 1:K )
    df$Cluster = as.factor( df$Cluster) 
    if (!is.null(exK)) {
	 df = df[ ! df$Cluster %in% exK, ]
    }
    p =  ggplot( df, aes( x = "", y = diff  ) ) +  
	    geom_boxplot( fill = "grey", alpha = 0.3 , outlier.size = 0) + geom_jitter( width = 0.2, aes( color = Cluster )  ) + 
	    ylab("Difference of average silhouette\nwidth within cluster") +  xlab("") +  
	    guides(fill=guide_legend(title="Cluster") ) + 
       	    scale_color_manual( values= color ) + 
	    theme( panel.background = element_rect(fill="white", color="grey"),
		  axis.text.y=element_text(size=8), axis.text.x=element_text(size=8), 
		  panel.grid=element_line("grey69") , axis.text = element_text( size = 10), 
		  text = element_text(size=10)   )  +   ggtitle("\nSilhouette width") 
    return( p) 
}
## Function to plot silhouette width (boxplot) for both original data and decontamintaed data
silhouette.plot = function( silhouette.ori, silhouette.dec, K, color ) { 
    sil.ori = summary( silhouette.ori) 
    sil.dec = summary( silhouette.dec) 
    df = data.frame(Original.data = sil.ori$clus.avg.widths, 
		    Decontaminated.data = sil.dec$clus.avg.widths, 
		    Cluster = 1:K )
    df$Cluster = as.factor( df$Cluster) 
    df.melt = reshape::melt( df, id.vars = "Cluster" ) 
    p =  ggplot( df.melt, aes( x = variable, y = value  ) ) +  
	    geom_boxplot( fill = "grey", alpha = 0.3 , outlier.size = 0) + geom_jitter( width = 0.2, aes( color = Cluster )  ) + 
	    ylab("Average silhouette width within cluster") +  xlab(" ") +  
	    guides(fill=guide_legend(title="Cluster") ) + 
       	    scale_color_manual( values= color ) + 
	    theme( panel.background = element_rect(fill="white", color="grey"),
		  panel.grid=element_line("grey69") , axis.text = element_text( size = 10), 
		  text = element_text(size=10)   )  +   ggtitle("Silhouette width") 
    return( p) 
}

## Function to match cell cluster label (z) to cell-type 
## infered from differential expression or experiment cell sorting label 
match.z.celltype = function( z, cellType.list   )  { 
	z.cell = z
	for ( i in 1:length(cellType.list) )  { 
            z.cell[ z %in% cellType.list[[i]]  ] =  names( cellType.list[i] ) 
       	}
	return( z.cell ) 
} 

## Function to normalize gene expression and calculate the average expression of selected genes in each cell-type group
normExp.ctype = function( counts, z.cell, genes, type="log2" ) { 
	counts = celda::normalizeCounts( counts, "cpm") 

	gene.name = gsub(".*_", "", rownames( counts) ) 
	rownames( counts ) = gene.name

	counts.select = counts[ rownames( counts) %in% genes,  ] 
	if( type== "none") {  }   
	if( type=="log2" ) { counts.select = log2(counts.select +1 ) } 
	if( type=="sqrt") { counts.select = sqrt( counts.select )  }  

	df.gene = data.frame( t( counts.select), cellType = z.cell )  
	return( df.gene ) 
} 

# Violin plot that takes output from normExp.ctype 
violinplot.g = function( gene.exp )  {
	        m = reshape2::melt( gene.exp, id.vars = "cellType")
 	        colnames( m) = c("CellType", "Gene",  "Expression" )
	        p = ggplot( m , aes( x = Gene,  y = Expression ,  fill = Gene ) ) + 
			geom_violin( trim=T, scale = "width" )  + facet_wrap( ~ CellType )
	        return( p )
}


## Function to create a 3-dim table table, with each element being the number of cells that have a specific gene observed (in any number)
gene.observed.tb = function( gene.exp,  gene.group=NULL , drop = TRUE  )  { 
    if( is.null(gene.group) )  { 
        a = reshape2::melt( gene.exp, id.vars = "cellType") 
        tb = table( a$cellType, a$variable, a$value >0 ) 
    } else { 
	gene.exp.2 = gene.exp 
        for ( i in names(gene.group)  ) { 
            N = sum( colnames( gene.exp.2 )  %in% gene.group[[i]] ) 
            if( N > 1 )  {
                gene.exp.2[, i] = rowSums( gene.exp.2[, colnames(gene.exp.2 ) %in% gene.group[[i]] ] ) 
	        if( drop == TRUE)  {  # drop original marker column
		    gene.exp.2 = gene.exp.2[, ! colnames( gene.exp.2 ) %in% gene.group[[i]] ]  
		} 
	    } else if ( N == 1) {
	        colnames(gene.exp.2)[ colnames( gene.exp.2)  ==  gene.group[[i]] ] = i
	    }
	}
        a = reshape2::melt( gene.exp.2, id.vars = "cellType" ) 
        tb = table( a$cellType, a$variable, a$value >0 ) 
    }
    return( tb ) 
} 

## Function to convert the output from gene.observed.tb to 2-dim table 
stack.tb = function( ori.tb , cellTypes ) { 
	a.gt0 = ori.tb[, , 2] 
	a.gt0 = a.gt0[ rownames( a.gt0) %in% cellTypes, ] 
	a.0 = ori.tb[, , 1]
	a.0 = a.0[ rownames( a.0) %in% cellTypes, ] 

	a.gt0.m = reshape2::melt( a.gt0 )  
	colnames( a.gt0.m) = c( "cellTypes", "genes", "gt0") 
	a.0.m = reshape2::melt( a.0 ) 
	colnames( a.0.m) = c( "cellTypes", "genes", "equal0") 
	m = merge( a.gt0.m, a.0.m, by = c("cellTypes", "genes" )  ) 
	return( m )  
} 

cat.stack = function( stackTB ) { 
	stackTB$`PercentageShowingTheMarkers_(%)`  = stackTB$gt0 /  (stackTB$gt0 + stackTB$equal0 ) * 100 
	print( stackTB) 
	return(0)
}

## Function to make stack plots (taking the output from stack.tb) 
plt.stackbar = function( m,  plot.status=NULL )  { 
	m$total = m$gt0 + m$equal0 
	m$genes = sub("*.marker", "", m$genes)
	t = reshape2::melt( m, id.vars=c("cellTypes", "genes", "total" ) ) 
	colnames( t)[4:5] = c( "exp.status", "cellCounts" ) 
	t$percent = round(t$cellCounts  / t$total  , 3 ) * 100 
	if( ! is.null( plot.status) )  { t = t[t$exp.status == plot.status, ] } 
	p = ggplot( t,  aes( x = genes, y = percent   ) ) + geom_bar( aes( fill = exp.status ), stat = "identity"  )  + 
		    facet_grid(. ~ cellTypes ) +  
		    #xlab("Gene markers") +   ylab("Percentage of cells presented expression (%)" ) + 
		    guides(fill=guide_legend(title="Expression level")) + 
		    scale_fill_manual( values=c( "red3", "dimgrey") )  +
		    geom_text(data =  t[ t$exp.status == "gt0",  ],
			      #aes(x = genes, y= percent + 5 ,label =paste0( percent, "%" )   ) , size = 2 ) +
			      aes(x = genes, y= percent + 5 ,label =percent ) , size = 3 ) +
 	                     theme(panel.background=element_rect(fill="white", color="grey"),
	                          panel.grid = element_line("grey"), legend.position="none",
	                          legend.key=element_rect(fill="white", color="white"),
   	                          panel.grid.minor = element_blank(),
				  panel.grid.major = element_blank(),
	                          text=element_text(size=10),
	       	                  axis.text.x = element_text(size=8, angle = 45, hjust = 1),
		                  axis.text.y=element_text(size=9),
		                  legend.key.size = grid::unit(8, "mm"),
			          legend.text = element_text(size=10), 
			          strip.text.x = element_text(size = 10)  )
                   theme( legend.position="none" ) 
	return( p)  
} 


#. Function to plot tsne labeling the doublet predicted by SCrublet 
plot.doublet = function( dim1, dim2, doubletPre, size = 1, varLabel, color = c("red4", "grey")  ) { 
	m = doubletPre
	df = data.frame( x = dim1, y = dim2, m = m ) 
	p = ggplot( df, aes( x = x, y = y) ) + geom_point( stat ="identity", size = size, aes(color = m) ) +
		xlab("Dimension_1") + ylab("Dimension_2") + 
		scale_color_manual( values = color) + 
               theme_bw() +
               theme(strip.background = element_blank(),
	             panel.grid.major = element_blank(),
	             panel.grid.minor = element_blank(),
	             panel.spacing = unit(0, "lines"),
                     panel.background = element_blank(),
		     axis.line = element_line(colour = "black"), 
				 text = element_text(size=8),
		     legend.title = element_text(size = 8)  
		     ) +
	       guides(colour = guide_legend(override.aes = list(alpha = 1, size = 2)))

       return(p ) 
}

# Function to plot tsne with predicted values (estimated-contamination in DecontX, or predited doublet-score in Scrublet) 
plot.est = function( dim1, dim2, scaleValue, size = 1, varLabel, colorLow = "grey80", colorHigh = "blue4", colorMid = NULL) { 
	m = scaleValue 
	df = data.frame( x = dim1, y = dim2, m = m ) 
	p = ggplot( df, aes( x = x, y = y) ) + geom_point( stat ="identity", size = size, aes(color = m) ) +
		xlab("Dimension_1") + ylab("Dimension_2") + 
	       scale_colour_gradient2(low = colorLow,high = colorHigh,mid = colorMid, guide = "colorbar",
				      midpoint = ( (max(m) + min(m))/ 2), name = varLabel ) + 
               theme_bw() +
               theme(strip.background = element_blank(),
	             panel.grid.major = element_blank(),
	             panel.grid.minor = element_blank(),
	             panel.spacing = unit(0, "lines"),
                     panel.background = element_blank(),
		     axis.line = element_line(colour = "black"), 
				 text = element_text(size=8),
		     legend.title = element_text(size = 8)
		     )  
                #guides( fill = guide_colorbar( barwidth = 0.5, barheight =5) )  
                #guides( fill = guide_colorbar(barwidth = 0.5, barheight = 3, label.theme = element_text(size = 6), 
		#			    label.hjust=-1, title.theme = element_text(size = 6), title.hjust = -1  )   ) 

       return(p ) 
}

# Function to make box plots of estimated values of DecontX and Scrublet 
plot.method = function( estConp, doublet, color = c("red4", "grey")) { 
       df = data.frame( estConp, doublet) 
       p = ggplot( df, aes( x = doublet, y = estConp ) ) + 
		  labs( color = "Prediction") + 
	          geom_boxplot( fill = "grey", alpha = 0.3 , outlier.size = 0) + 
		  geom_jitter( width = 0.2, alpha = 0.3, size = 0.3, aes(color = doublet)  ) + 
		  scale_color_manual( values = color ) + 
                  theme(panel.background = element_rect(fill="white", color="grey"),
		       	panel.grid=element_line("grey69") , axis.text = element_text( size = 8),
			text = element_text(size=8), legend.title = element_text(size = 8) ) + 
                  guides(colour = guide_legend(override.aes = list(alpha = 1, size = 2)))  
		  return( p) 
}


# Function to make violin plots of estimated values of DecontX and Scrublet  
plot.methodViol = function( estConp, doublet, color = c("red4", "grey")) { 
       df = data.frame( estConp, doublet) 
       p = ggplot( df, aes( x = doublet, y = estConp) ) + 
		  labs( color = "Prediction") + 
		  geom_jitter( width = 0.2, alpha = 1, size = 0.3, aes(color = doublet)  ) + 
		  geom_violin( trim=T, scale = "width", fill = "grey", alpha = 0.5 ) + 
		  scale_color_manual( values = color ) + 
                  theme(panel.background = element_rect(fill="white", color="grey"),
		       	panel.grid=element_line("grey69") , axis.text = element_text( size = 10),
			text = element_text(size=10), legend.title = element_text(size = 8) ) + 
                  guides(colour = guide_legend(override.aes = list(alpha = 1, size = 2)))  
		  return( p) 
}

# Function to plot histgram/distribution of silhouette width 
histgram.silhouette = function(sil.obj.pre, sil.obj.pos, cluster, position="dodge") {
  # the 1st column of silhouette obejct is `cluster`
	# 2nd column is `neighbor`
	# 3rd column is `sil_width`
	pre.index = sil.obj.pre[, "cluster"] %in% cluster 
  df.pre = data.frame( "type" = "pre", "cluster" = sil.obj.pre[pre.index, "cluster"], "sil_width" = sil.obj.pre[pre.index, "sil_width"] )
	pos.index = sil.obj.pos[, "cluster"] %in% cluster
	df.pos = data.frame( "type" = "pos", "cluster" = sil.obj.pos[pos.index, "cluster"], "sil_width" = sil.obj.pos[pre.index, "sil_width"] )
	df.concat = rbind(df.pre, df.pos)
	p = ggplot(df.concat, aes(x = sil_width, fill = type)) + 
		geom_histogram(aes(y=..density..),  position=position, alpha = 0.5) +
		geom_density(alpha=0.1, aes(color = type), fill = "white") + 
		xlab("Silhouette width") + ylab("Density") +
		scale_fill_manual(values=c("#999999", "#E69F00"), labels = c("Original counts", "Decontaminated counts")) +
		scale_color_manual(values=c("#999999", "#E69F00"), labels = c("Original counts", "Decontaminated counts")) + 
		labs( color = "  ") + 
      theme(text=element_text(size=10 ),
			axis.text.x = element_text(size=8),
			axis.text.y = element_text(size=8),
			panel.background=element_blank(),
			panel.grid = element_blank(),
			axis.line = element_line(colour = "black"),
			legend.key=element_rect(fill="white", color="white"),
			legend.title = element_text(size = 8)
			) + 
      facet_wrap( ~ cluster, scale = "free")
return(p)
}

# histgram of silhouette width
RNGkind(sample.kind="Rounding")  
set.seed(12345)
color19 = celda::distinctColors(19)
histgram.silhouette_deprecated = function(sil.obj.pre, sil.obj.pos, cluster, position="dodge") {
  # the 1st column of silhouette obejct is `cluster`
	# 2nd column is `neighbor`
	# 3rd column is `sil_width`
	pre.index = sil.obj.pre[, "cluster"] %in% cluster 
  df.pre = data.frame( "type" = "pre", "cluster" = sil.obj.pre[pre.index, "cluster"], "sil_width" = sil.obj.pre[pre.index, "sil_width"] )
	pos.index = sil.obj.pos[, "cluster"] %in% cluster
	df.pos = data.frame( "type" = "pos", "cluster" = sil.obj.pos[pos.index, "cluster"], "sil_width" = sil.obj.pos[pre.index, "sil_width"] )
	df.concat = rbind(df.pre, df.pos)
	df.concat[, "clusterNtype"] = paste0(df.concat$type, df.concat$cluster)
	df.concat$clusterNtype[ df.concat$type == "pre" ] = "pre"
	df.concat$clusterNtype = factor(df.concat$clusterNtype, levels = c("pre", paste0("pos", 1:19)) )
	label = c("Original counts", paste0("Decontamianted cluster ", 1:19) )
	p = ggplot(df.concat, aes(x = sil_width, fill = clusterNtype)) + 
		geom_histogram(aes(y=..density..),  position=position, alpha = 0.5) +
		geom_density(alpha=0.1, aes(color = type), fill = "white") + 
		xlab("Silhouette width") + ylab("Density") +
		scale_fill_manual(values=c("#999999", color19), labels = label) + 
		scale_color_manual(values=c("#999999", "#E69F00"), labels = c("Original counts", "Decontaminated counts")) + 
		labs( color = "  ") + 
      theme(text=element_text(size=10 ),
			axis.text.x = element_text(size=8),
			axis.text.y = element_text(size=8),
			panel.background=element_blank(),
			panel.grid = element_blank(),
			axis.line = element_line(colour = "black"),
			legend.key=element_rect(fill="white", color="white"),
			legend.title = element_text(size = 8)
			) + 
      facet_wrap( ~ cluster)
return(p)
}


# Function to make violin plots of estimated values of DecontX and Scrublet  
plot.dataViolin = function( estConp, color = c("red4", "grey", "yellow", "green", "black")) { 
       df = estConp
       p = ggplot( df, aes( x = data, y = estConp) ) + 
		  labs( color = "Cluster") + 
			ylab("Estimated Contamination by DecontX") + 
			xlab("Dataset") +
		  geom_jitter( width = 0.2, alpha = 1, size = 0.3, aes(color = as.factor(cluster))  ) + 
		  geom_violin( trim=T, scale = "width", fill = "grey", alpha = 0.5 ) + 
		  scale_color_manual( values = color ) + 
                  guides(colour = guide_legend(override.aes = list(alpha = 1, size = 2)))  +  
									 theme(panel.background=element_rect(fill="white", color="grey"),
												 panel.grid = element_line("grey"),
												 #legend.position="none",
												 legend.key=element_rect(fill="white", color="white"),
											 panel.grid.minor = element_blank(),
	                     panel.grid.major = element_blank(),
											 text=element_text(size=10),
											 axis.text.x = element_text(size=8, angle = 45, hjust = 1),
											 #axis.text.x = element_text(size=8),
											 axis.text.y=element_text(size=9),
											 legend.key.size = grid::unit(8, "mm"),
											 legend.text = element_text(size=8),
											 legend.title = element_text(size = 8),
											 strip.text.x = element_text(size = 10)  )   
return( p) 
}



# Functions that plot cluster 
plot.cluster = function( dim1, dim2, cluster , size = 1, varLabel, color = color19  ) { 
	m = factor(cluster) 
	df = data.frame( x = dim1, y = dim2, m = m ) 
	p = ggplot( df, aes( x = x, y = y) ) + geom_point( stat ="identity", size = size, aes(color = m) ) +
		xlab("Dimension_1") + ylab("Dimension_2") + 
		scale_color_manual( values = color) + 
               theme_bw() +
               theme(strip.background = element_blank(),
	             panel.grid.major = element_blank(),
	             panel.grid.minor = element_blank(),
	             panel.spacing = unit(0, "lines"),
                     panel.background = element_blank(),
		     axis.line = element_line(colour = "black"), 
		     legend.title = element_text(size = 8)  
		     ) +
	       guides(colour = guide_legend(override.aes = list(alpha = 1, size = 2), title = varLabel))

       return(p ) 
}


# Function to make violin plots of total UMIs for each cluster
plot.UMIsViolin = function( counts, cluster,  color =color19, xlab = "cluster", ylab = "Total UMIs", labs = "Cluster") { 
       df = data.frame( "UMIs" = colSums(counts) , "cluster" = factor(cluster) )
       df$medianUMIs = ""
			 df$UMIs.pct = ""
      for (c in unique(cluster) ) {
				df$medianUMIs[cluster == c][1] = round(median(df$UMIs[cluster == c]))
        df$UMIs.pct[cluster == c][1] = paste0("(", round(sum(df$UMIs[ cluster == c]) / sum(df$UMIs) * 100, 2), "%)")
			}
       p = ggplot( df, aes( x = cluster, y = UMIs) ) + 
		  labs( color = labs) + 
			ylab(ylab)+ 
			xlab(xlab) +
		  geom_jitter( width = 0.2, alpha = 1, size = 0.3, aes(color = cluster )  ) + 
		  geom_violin( trim=T, scale = "width", fill = "grey", alpha = 0.5, aes(color = cluster) ) + 
		  scale_color_manual( values = color ) + 
                  guides(colour = guide_legend(override.aes = list(alpha = 1, size = 2)))  +  
									 theme(panel.background=element_rect(fill="white", color="grey"),
												 panel.grid = element_line("grey"),
												 #legend.position="none",
												 legend.key=element_rect(fill="white", color="white"),
											 panel.grid.minor = element_blank(),
	                     panel.grid.major = element_blank(),
											 text=element_text(size=10),
											 #axis.text.x = element_text(size=8, angle = 45, hjust = 1),
											 axis.text.x = element_text(size=8),
											 axis.text.y=element_text(size=8),
											 legend.key.size = grid::unit(8, "mm"),
											 legend.text = element_text(size=8),
											 legend.title = element_text(size = 8),
											 strip.text.x = element_text(size = 10)  )   
return( p) 
}

# Function to make violin plots of estimated values of DecontX and Scrublet  
plot.estConpViolin = function( estConp, cluster,  color =color19) { 
       df = data.frame( "estConp" = estConp , "cluster" = factor(cluster) )
       p = ggplot( df, aes( x = cluster, y = estConp) ) + 
		  labs( color = "Cluster") + 
			ylab("Estimated\ncontamination (%)") + 
			xlab("Cluster") +
		  geom_jitter( width = 0.2, alpha = 1, size = 0.3, aes(color = cluster )  ) + 
		  geom_violin( trim=T, scale = "width", fill = "grey", alpha = 0.5, aes(color = cluster) ) + 
		  scale_color_manual( values = color ) + 
                  guides(colour = guide_legend(override.aes = list(alpha = 1, size = 2)))  +  
									 theme(panel.background=element_rect(fill="white", color="grey"),
												 panel.grid = element_line("grey"),
												 #legend.position="none",
												 legend.key=element_rect(fill="white", color="white"),
											 panel.grid.minor = element_blank(),
	                     panel.grid.major = element_blank(),
											 text=element_text(size=10),
											 #axis.text.x = element_text(size=8, angle = 45, hjust = 1),
											 axis.text.x = element_text(size=8),
											 axis.text.y=element_text(size=8),
											 legend.key.size = grid::unit(8, "mm"),
											 legend.text = element_text(size=8),
											 legend.title = element_text(size = 8),
											 strip.text.x = element_text(size = 10)  )   
return( p) 
}


# Function to get marker gene expressions for each cell within gene's corresponding cell type 
marker.counts.tb = function(counts, z.cell, gene.group, cellType, onlyMarkers = TRUE) {
	  markers = do.call(base::c, gene.group)
  names(markers) = gsub("(.*)(\\..*)", "\\1", names(markers))
	  totalUMIs = colSums(counts)
	  gene.names = gsub(".*_", "", rownames( counts) )
		  rownames(counts) = gene.names
		  counts = counts[ gene.names %in% markers,  ]

			if (onlyMarkers == TRUE) {
			  tb.list = lapply(cellType, function(cType) {
									 tb.cType = counts[, z.cell == cType]
									 tb.cType = tb.cType[ rownames(tb.cType) %in% markers[names(markers) == cType] , ]
									 if ( is.null(dim(tb.cType)) ) {
											 tb.melt = data.frame( "genes" = rownames(counts)[ rownames(counts) %in% markers[names(markers) == cType] ], "cell" = names(tb.cType), "counts" = tb.cType)
									 } else {
											 tb.melt = reshape2::melt(tb.cType)
										 colnames(tb.melt) = c( "genes", "cell",  "counts")
									 }
                	 tb.melt$cellType = cType
                	 return(tb.melt)
					 } ) 
				} else {  # calculate expression for all availabel genes 
					Genes = markers[ names(markers) %in% cellType ]
					tb.list = lapply(cellType, function(cType) {
						tb.cType = counts[, z.cell == cType]
						tb.cType = tb.cType[ rownames(tb.cType) %in% Genes , ]
						if ( is.null(dim(tb.cType)) ) {
								tb.melt = data.frame( "genes" = rownames(counts)[ rownames(counts) %in%  Genes  ], "cell" = names(tb.cType), "counts" = tb.cType)
						} else {
								tb.melt = reshape2::melt(tb.cType)
								colnames(tb.melt) = c( "genes", "cell",  "counts")		
						}
						tb.melt$cellType = cType
						return(tb.melt)
						} )
}

		tb.melt = do.call( rbind, tb.list)
		return(tb.melt)
}

# Function to plot jittered dodge points for distribution of marker genes expression in each cell type
plot.markerUMIs = function(tb.melt, color = color19) {
	tb = tb.melt
	tb$Genes = tb$genes
	p = ggplot(tb, aes( x = cellType, y = counts)) +
		         #geom_jitter( width = 0.3, alpha = 1, size = 0.3, aes(color = genes)  ) +
		          geom_point(size = 0.3,  aes(fill = Genes, color = Genes), position = position_jitterdodge(jitter.width = 0.5, jitter.height = 0,  dodge.width = 0.75, seed = NA)) +
							         geom_violin( trim=T, scale = "width", fill = "grey", alpha = 0.4 , color = "grey", draw_quantiles= c(0.5)) +
											 xlab("Cell type") +
											 ylab("UMI counts") +
												 #scale_color_manual( values = color ) +
												 #scale_fill_manual( values = color) +
												 guides(fill= guide_legend(override.aes = list(alpha = 1, size = 2 ), ncol=2) )  +
												 #guides(fill= guide_legend(override.aes = list(alpha = 1, size = 2 )) )  +
																	 theme(panel.background=element_rect(fill="white", color="grey"),
																	 panel.grid = element_line("grey"),
																	 legend.key=element_rect(fill="white", color="white"),
																	 panel.grid.minor = element_blank(),
																	 panel.grid.major = element_blank(),
																	 text=element_text(size=10),
																	 #axis.text.x = element_text(size=8, angle = 45, hjust = 1),
									                 axis.text.x = element_text(size=8),
																	 axis.text.y=element_text(size=9),
																	 legend.key.size = grid::unit(8, "mm"),
																	 legend.text = element_text(size=8),
																	 legend.title = element_text(size = 8),
																	 strip.text.x = element_text(size = 10)  )
return(p)
}


# Function to plot jittered dodge points for distribution of marker genes expression in each cell type
plot.genesUMIs = function(tb.melt, color = color19) {
	tb = tb.melt
	tb$Genes = tb$genes
	p = ggplot(tb, aes( x = Genes, y = counts )) +
		         #geom_jitter( width = 0.3, alpha = 1, size = 0.3, aes(color = genes)  ) +
		          geom_point(size = 0.3,  aes(fill = Data, color = Data), position = position_jitterdodge(jitter.width = 0.4, jitter.height = 0,  dodge.width = 0.75, seed = NA)) +
							         geom_violin( trim=T, scale = "width", fill = "grey", alpha = 0.4 , aes(color = Data)  , draw_quantiles= c(0.5)) +
											 xlab("Genes") +
											 ylab("UMI counts") +
												 #scale_color_manual( values = color ) +
												 #scale_fill_manual( values = color) +
												 guides(fill= guide_legend(override.aes = list(alpha = 1, size = 2 ), ncol=2) )  +
												 #guides(fill= guide_legend(override.aes = list(alpha = 1, size = 2 )) )  +
																	 theme(panel.background=element_rect(fill="white", color="grey"),
																	 panel.grid = element_line("grey"),
																	 legend.key=element_rect(fill="white", color="white"),
																	 panel.grid.minor = element_blank(),
																	 panel.grid.major = element_blank(),
																	 text=element_text(size=10),
																	 #axis.text.x = element_text(size=8, angle = 45, hjust = 1),
									                 axis.text.x = element_text(size=8),
																	 axis.text.y=element_text(size=9),
																	 legend.key.size = grid::unit(8, "mm"),
																	 legend.text = element_text(size=8),
																	 legend.title = element_text(size = 8),
																	 strip.text.x = element_text(size = 10)  )
return(p)
}



# >>>>>>  functions for paper.R 
reorder.fun = function( mat ) { 
nRow = nrow( mat)
nCol = ncol( mat )
rownames( mat ) = as.character(1: nRow)
colnames( mat ) = as.character(1: nCol)
	for ( i in 1:nRow)  {
		index =  which.max( mat[i, ] )
		if ( index != i )  { 
			col.names = colnames( mat) [ c( index, i )  ] 
			mat[ , c( i, index) ] = mat[, c(index, i) ]  
			colnames( mat ) [ c(i, index) ]  = col.names 
		}
	}
	return( mat )
}



