# load data 
data = load("/restricted/projectnb/camplab/home/syyang/contamination/data/cellBenchData/CellBench_data_08112019/data/sincell_with_class_5cl.RData") 

cell.lines = c("H838", "H1975", "A549", "H2228", "HCC827") 


counts.n.z = function(sce, cellLine=cell.lines) { 
    counts = sce@assays$data$counts
    z_demuxlet = sce@colData$cell_line_demuxlet
    z.int = plyr::mapvalues(x=z_demuxlet, from = cellLine, to = 1:length(cellLine) ) 
    z.int = as.integer(z.int) 
    return(list("counts" = counts, "z_demuxlet"= z_demuxlet, "z" = z.int) )   
}


get.10x = counts.n.z( sce= sce_sc_10x_5cl_qc ) 


# Run DecontX
RNGkind(sample.kind = "Rounding")
library(devtools)
load_all("~/gitProjects/celda_irisapo", recompile=T)   # on fix branch, celda version 1.3.1



set.seed(12345)
dcon = decontX( counts = get.10x$counts , z = get.10x$z) 
saveRDS( dcon, "dcon.10x.rds" )  
