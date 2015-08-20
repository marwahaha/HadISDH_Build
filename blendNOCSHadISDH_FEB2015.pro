pro blendNOCSHadISDH_FEB2015

; Modified to read in from already created NOCS grids:
; extract_NOCSvars_FEB2014.pro
;	> UPDATE2014/OTHERDATA/NOCSv2.0_ocean*


anomyes=1	;0=anomalies, 1=absolutes

if (anomyes EQ 0) THEN outfil='/data/local/hadkw/HADCRUH2/UPDATE2014/STATISTICS/GRIDS/BLEND_NOCSv2.0_HadISDH.landq.2.0.1.2014p_8110_FEB2015.nc' $
                  ELSE outfil='/data/local/hadkw/HADCRUH2/UPDATE2014/STATISTICS/GRIDS/BLEND_NOCSv2.0_HadISDH.landq.2.0.1.2014p_abs_FEB2015.nc'


mdi=-1e30
styr=1973
edyr=2014
clst=1981-styr
cled=2010-styr
nyrs=(edyr+1)-styr
nmons=nyrs*12
int_mons=indgen(nmons)

nlons=72
nlats=36
lons=(findgen(nlons)*5.)-177.5
lats=(findgen(nlats)*(-5.))+87.5
lats=REVERSE(lats)

landarr=make_array(nlons,nlats,nmons,/float,value=mdi)
marinelow=make_array(nlons,nlats,nmons,/float,value=mdi)
marinelowmask=make_array(nlons,nlats,nmons,/float,value=mdi)
blendarr=make_array(nlons,nlats,nmons,/float,value=mdi)
blendarrmask=make_array(nlons,nlats,nmons,/float,value=mdi)
bluemasklow=fltarr(72,36)

; read in land sea mask
inn=NCDF_OPEN('/data/local/hadkw/HADCRUH2/UPDATE2014/OTHERDATA/new_coverpercentjul08.nc')
varid=NCDF_VARID(inn,'pct_land')
NCDF_VARGET,inn,varid,pctl
NCDF_CLOSE,inn

pctl=REVERSE(pctl,2)

; read in NOCS
indir='/data/local/hadkw/HADCRUH2/UPDATE2014/OTHERDATA/'
IF (anomyes EQ 0) THEN BEGIN
  inn=NCDF_OPEN(indir+'NOCSv2.0_oceanq_5by5_8110anoms_FEB2015.nc') 
  varid=NCDF_VARID(inn,'q_anoms')	;1=good
  maskvarid=NCDF_VARID(inn,'mask_q_anoms')	;1=good
ENDIF ELSE BEGIN
  inn=NCDF_OPEN(indir+'NOCSv2.0_oceanq_5by5_abs_FEB2015.nc')
  varid=NCDF_VARID(inn,'q_abs')	;1=good
  maskvarid=NCDF_VARID(inn,'mask_q_abs')	;1=good
ENDELSE
NCDF_VARGET,inn,varid,marinelow
NCDF_VARGET,inn,maskvarid,marinelowmask
NCDF_CLOSE,inn

; read in HadISDH data and renormalise to 1981-2010
; could also mask by where uncertainties are larger than the standard deviation
inn=NCDF_OPEN('/data/local/hadkw/HADCRUH2/UPDATE2014/STATISTICS/GRIDS/HadISDH.landq.2.0.1.2014p_FLATgridIDPHA5by5_JAN2015_cf.nc')
IF (anomyes EQ 0) THEN varid=NCDF_VARID(inn,'q_anoms') ELSE varid=NCDF_VARID(inn,'q_abs') 
NCDF_VARGET,inn,varid,landarr
NCDF_CLOSE,inn

if (anomyes EQ 0) THEN BEGIN
  FOR i=0,nlons-1 DO BEGIN
    FOR j=0,nlats-1 DO BEGIN
      subarr=landarr(i,j,*)
      gots=WHERE(subarr NE mdi,count)
      IF (count GT nmons/2) THEN BEGIN	; no point if there isn't much data
        monarr=REFORM(subarr,12,nyrs)
        FOR mm=0,11 DO BEGIN
          submon=monarr(mm,*)
	  gots=WHERE(submon NE mdi,count)
	  IF (count GT 20) THEN BEGIN
	    clims=submon(clst:cled)
	    gotclims=WHERE(clims NE mdi,count)
	    IF (count GT 15) THEN submon(gots)=submon(gots)-MEAN(clims(gotclims))
	  ENDIF ELSE submon(*,*)=mdi
	  monarr(mm,*)=submon
        ENDFOR
        landarr(i,j,*)=REFORM(monarr,nmons)
      ENDIF ELSE landarr(i,j,*)=mdi
    ENDFOR
  ENDFOR
ENDIF

; blend using coastal gridboxes as 25-75% weighting
; adjust pctl such that when value is not 0 or 100 it is at least 25 or max 75
; thus land and sea in coastal boxes will always be represented
lows=WHERE(pctl LT 25. AND pctl NE 0.,count)
IF (count GT 0) THEN pctl(lows)=25.
highs=WHERE(pctl GT 75. AND pctl NE 100.,count)
IF (count GT 0) THEN pctl(highs)=75.

FOR i=0,nlons-1 DO BEGIN
  FOR j=0,nlats-1 DO BEGIN
    FOR nn=0,nmons-1 DO BEGIN
      IF (pctl(i,j) EQ 100.) THEN BEGIN
        IF (marinelow(i,j,nn) EQ mdi) AND (landarr(i,j,nn) NE mdi) THEN blendarr(i,j,nn)=landarr(i,j,nn)
        IF (marinelow(i,j,nn) NE mdi) AND (landarr(i,j,nn) EQ mdi) THEN blendarr(i,j,nn)=marinelow(i,j,nn)
	IF (marinelow(i,j,nn) NE mdi) AND (landarr(i,j,nn) NE mdi) THEN blendarr(i,j,nn)=$
	   (marinelow(i,j,nn)*0.25)+(landarr(i,j,nn)*0.75)	
        IF (marinelowmask(i,j,nn) EQ mdi) AND (landarr(i,j,nn) NE mdi) THEN blendarrmask(i,j,nn)=landarr(i,j,nn)
        IF (marinelowmask(i,j,nn) NE mdi) AND (landarr(i,j,nn) EQ mdi) THEN blendarrmask(i,j,nn)=marinelowmask(i,j,nn)
	IF (marinelowmask(i,j,nn) NE mdi) AND (landarr(i,j,nn) NE mdi) THEN blendarrmask(i,j,nn)=$
	   (marinelowmask(i,j,nn)*0.25)+(landarr(i,j,nn)*0.75)	
     ENDIF ELSE IF (pctl(i,j) EQ 0.) THEN BEGIN
        IF (marinelow(i,j,nn) EQ mdi) AND (landarr(i,j,nn) NE mdi) THEN blendarr(i,j,nn)=landarr(i,j,nn)
        IF (marinelow(i,j,nn) NE mdi) AND (landarr(i,j,nn) EQ mdi) THEN blendarr(i,j,nn)=marinelow(i,j,nn)
	IF (marinelow(i,j,nn) NE mdi) AND (landarr(i,j,nn) NE mdi) THEN blendarr(i,j,nn)=$
	   (marinelow(i,j,nn)*0.75)+(landarr(i,j,nn)*0.25)	
        IF (marinelowmask(i,j,nn) EQ mdi) AND (landarr(i,j,nn) NE mdi) THEN blendarrmask(i,j,nn)=landarr(i,j,nn)
        IF (marinelowmask(i,j,nn) NE mdi) AND (landarr(i,j,nn) EQ mdi) THEN blendarrmask(i,j,nn)=marinelowmask(i,j,nn)
	IF (marinelowmask(i,j,nn) NE mdi) AND (landarr(i,j,nn) NE mdi) THEN blendarrmask(i,j,nn)=$
	   (marinelowmask(i,j,nn)*0.75)+(landarr(i,j,nn)*0.25)	
      ENDIF ELSE BEGIN
        IF (marinelow(i,j,nn) EQ mdi) AND (landarr(i,j,nn) NE mdi) THEN blendarr(i,j,nn)=landarr(i,j,nn)
        IF (marinelow(i,j,nn) NE mdi) AND (landarr(i,j,nn) EQ mdi) THEN blendarr(i,j,nn)=marinelow(i,j,nn)
	IF (marinelow(i,j,nn) NE mdi) AND (landarr(i,j,nn) NE mdi) THEN blendarr(i,j,nn)=$
	   (marinelow(i,j,nn)*((100.-pctl(i,j))/100.))+(landarr(i,j,nn)*(pctl(i,j)/100.))	
        IF (marinelowmask(i,j,nn) EQ mdi) AND (landarr(i,j,nn) NE mdi) THEN blendarrmask(i,j,nn)=landarr(i,j,nn)
        IF (marinelowmask(i,j,nn) NE mdi) AND (landarr(i,j,nn) EQ mdi) THEN blendarrmask(i,j,nn)=marinelowmask(i,j,nn)
	IF (marinelowmask(i,j,nn) NE mdi) AND (landarr(i,j,nn) NE mdi) THEN blendarrmask(i,j,nn)=$
	   (marinelowmask(i,j,nn)*((100.-pctl(i,j))/100.))+(landarr(i,j,nn)*(pctl(i,j)/100.))	
      ENDELSE
    ENDFOR  
  ENDFOR
ENDFOR

; output gridded product

wilma=NCDF_CREATE(outfil,/clobber)
  
tid=NCDF_DIMDEF(wilma,'time',nmons)
clmid=NCDF_DIMDEF(wilma,'month',12)
latid=NCDF_DIMDEF(wilma,'latitude',nlats)
lonid=NCDF_DIMDEF(wilma,'longitude',nlons)
  
timesvar=NCDF_VARDEF(wilma,'times',[tid],/SHORT)
latsvar=NCDF_VARDEF(wilma,'latitude',[latid],/FLOAT)
lonsvar=NCDF_VARDEF(wilma,'longitude',[lonid],/FLOAT)
IF (anomyes EQ 0) THEN BEGIN
  Bqhumanomvar=NCDF_VARDEF(wilma,'blend_q_anoms',[lonid,latid,tid],/FLOAT)
  Bqhumanomvarmask=NCDF_VARDEF(wilma,'blendmask_q_anoms',[lonid,latid,tid],/FLOAT)
ENDIF ELSE BEGIN
  Bqhumanomvar=NCDF_VARDEF(wilma,'blend_q_abs',[lonid,latid,tid],/FLOAT)
  Bqhumanomvarmask=NCDF_VARDEF(wilma,'blendmask_q_abs',[lonid,latid,tid],/FLOAT)
ENDELSE

NCDF_ATTPUT,wilma,'times','long_name','time'
NCDF_ATTPUT,wilma,'times','units','months beginning Jan 1970'
NCDF_ATTPUT,wilma,'times','axis','T'
NCDF_ATTPUT,wilma,'times','calendar','gregorian'
NCDF_ATTPUT,wilma,'times','valid_min',0.
NCDF_ATTPUT,wilma,'latitude','long_name','Latitude'
NCDF_ATTPUT,wilma,'latitude','units','Degrees'
NCDF_ATTPUT,wilma,'latitude','valid_min',-90.
NCDF_ATTPUT,wilma,'latitude','valid_max',90.
NCDF_ATTPUT,wilma,'longitude','long_name','Longitude'
NCDF_ATTPUT,wilma,'longitude','units','Degrees'
NCDF_ATTPUT,wilma,'longitude','valid_min',-180.
NCDF_ATTPUT,wilma,'longitude','valid_max',180.

IF (anomyes EQ 0) THEN BEGIN
  NCDF_ATTPUT,wilma,'blend_q_anoms','long_name','Blended Specific Humidity monthly mean anomaly (1981-2010)'
  NCDF_ATTPUT,wilma,'blend_q_anoms','units','g/kg'
  NCDF_ATTPUT,wilma,'blend_q_anoms','axis','T'
  valid=WHERE(blendarr NE mdi, tc)
  IF tc GE 1 THEN BEGIN
    min_t=MIN(blendarr(valid))
    max_t=MAX(blendarr(valid))
    NCDF_ATTPUT,wilma,'blend_q_anoms','valid_min',min_t(0)
    NCDF_ATTPUT,wilma,'blend_q_anoms','valid_max',max_t(0)
  ENDIF
  NCDF_ATTPUT,wilma,'blend_q_anoms','missing_value',mdi

  NCDF_ATTPUT,wilma,'blendmask_q_anoms','long_name','Marine High Quality Mask Blended Specific Humidity monthly mean anomaly (1981-2010)'
  NCDF_ATTPUT,wilma,'blendmask_q_anoms','units','g/kg'
  NCDF_ATTPUT,wilma,'blendmask_q_anoms','axis','T'
  valid=WHERE(blendarrmask NE mdi, tc)
  IF tc GE 1 THEN BEGIN
    min_t=MIN(blendarrmask(valid))
    max_t=MAX(blendarrmask(valid))
    NCDF_ATTPUT,wilma,'blendmask_q_anoms','valid_min',min_t(0)
    NCDF_ATTPUT,wilma,'blendmask_q_anoms','valid_max',max_t(0)
  ENDIF
  NCDF_ATTPUT,wilma,'blendmask_q_anoms','missing_value',mdi
ENDIF ELSE BEGIN
  NCDF_ATTPUT,wilma,'blend_q_abs','long_name','Blended Specific Humidity monthly mean'
  NCDF_ATTPUT,wilma,'blend_q_abs','units','g/kg'
  NCDF_ATTPUT,wilma,'blend_q_abs','axis','T'
  valid=WHERE(blendarr NE mdi, tc)
  IF tc GE 1 THEN BEGIN
    min_t=MIN(blendarr(valid))
    max_t=MAX(blendarr(valid))
    NCDF_ATTPUT,wilma,'blend_q_abs','valid_min',min_t(0)
    NCDF_ATTPUT,wilma,'blend_q_abs','valid_max',max_t(0)
  ENDIF
  NCDF_ATTPUT,wilma,'blend_q_abs','missing_value',mdi

  NCDF_ATTPUT,wilma,'blendmask_q_abs','long_name','Marine High Quality Mask Blended Specific Humidity monthly mean'
  NCDF_ATTPUT,wilma,'blendmask_q_abs','units','g/kg'
  NCDF_ATTPUT,wilma,'blendmask_q_abs','axis','T'
  valid=WHERE(blendarrmask NE mdi, tc)
  IF tc GE 1 THEN BEGIN
    min_t=MIN(blendarrmask(valid))
    max_t=MAX(blendarrmask(valid))
    NCDF_ATTPUT,wilma,'blendmask_q_abs','valid_min',min_t(0)
    NCDF_ATTPUT,wilma,'blendmask_q_abs','valid_max',max_t(0)
  ENDIF
  NCDF_ATTPUT,wilma,'blendmask_q_abs','missing_value',mdi
ENDELSE

current_time=SYSTIME()
NCDF_ATTPUT,wilma,/GLOBAL,'file_created',STRING(current_time)
NCDF_CONTROL,wilma,/ENDEF

NCDF_VARPUT, wilma,timesvar, int_mons
NCDF_VARPUT, wilma,latsvar, lats
NCDF_VARPUT, wilma,lonsvar, lons
NCDF_VARPUT, wilma,Bqhumanomvar,blendarr
NCDF_VARPUT, wilma,Bqhumanomvarmask,blendarrmask

NCDF_CLOSE,wilma


stop
end
