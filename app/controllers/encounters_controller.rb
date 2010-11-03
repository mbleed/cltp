class EncountersController < ApplicationController
  # GET /encounters
  # GET /encounters.xml
  def index
    if @user.primary_role == "Student"
      @encounters = Encounter.all_by_user(@user.id)
      @page_title = "My Encounters"
    else
      @encounters = Encounter.all
      @page_title = "All Encounters"
    end

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @encounters }
    end
  end

  # GET /encounters/1
  # GET /encounters/1.xml
  def show
   	@encounter = Encounter.find(params[:id])
    
    # allow student to view only their own encounters
    if (@user.primary_role == "Student") && (@encounter.created_by != @user.id)
      render :file => "public/401.html", :status => :unauthorized 
      return
    end

	  @encounterDiagnoses = @encounter.diagnoses
	  @encounterProcedures = @encounter.procedures
      @resources = Resource.find_by_encounter(@encounter.id)
      @rel_resources = Resource.find_related_by_encounter(@encounter.id, 
        @user.id, @user.primary_role)
    
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @encounter }
    end
  end

  # GET /encounters/new
  # GET /encounters/new.xml
  def new	
    if @user.primary_role != "Student"
      render :file => "public/401.html", :status => :unauthorized 
      return
    end
    
  	@clerkship = Clerkship.find_by_name('Pediatrics')    

	  @encounter = Encounter.new
	  @cs = CareSetting.all
	  @clinics = Clinic.all
	  @dxcs = DiagnosisCategory.find_all_by_clerkship_id(@clerkship.id)
    @dxs = Diagnosis.find_all_by_clerkship_id(@clerkship.id)
    @procedures = Procedure.find_all_by_clerkship_id([@clerkship.id, -1]) 
    
    @dxbycats = Diagnosis.dx_by_categories(@clerkship.id)
    @dx_names = @dxbycats.map { |dxc| "'#{dxc.category_name} > #{dxc.name}'"}.join(",")
    @dx_hash = @dxbycats.map { |dxc| "'#{dxc.category_name} > #{dxc.name}' : #{dxc.id}"}.join(",")
    @proc_names = @procedures.collect { |proc| "'#{proc.name}'" }.join(",")
    @proc_hash = @procedures.collect { |proc| "'#{proc.name}' : #{proc.id}" }.join(",")
    
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @encounter }
    end
  end
  
  # GET /encounters/get_clerkships_by_care_setting/OP
  # GET /encounters/get_clerkships_by_care_setting/OP.xml
  def get_clerkships_by_care_setting
	  @clinics = Clinic.find_all_by_care_setting(params[:id])
    
    respond_to do  |format|
      format.html { redirect_to encounters_path }
      format.js {render :layout => false}
    end
  end
    
  # GET /encounters/writeup
  # GET /encounters/writeup.xml
  def resource_details
    @encounter = Encounter.find(params[:id])
	#render :layout => "layouts/popup"
    respond_to do |format|
      format.html # writeup.html.erb
      format.xml  { render :xml => @encounter }
    end
  end

  # GET /encounters/edit/1
  def edit
    if @user.primary_role != "Student"
      render :file => "public/401.html", :status => :unauthorized 
      return
    end
    
    @encounter = Encounter.find(params[:id])
    @encounterDiagnoses = @encounter.diagnoses
	  @encounterProcedures = @encounter.procedures
    @clerkship = Clerkship.find_by_name('Pediatrics')    
	  @cs = CareSetting.all
	  @clinics = Clinic.all
	  @dxcs = DiagnosisCategory.find_all_by_clerkship_id(@clerkship.id)
    @dxs = Diagnosis.find_all_by_clerkship_id(@clerkship.id)
    @procedures = Procedure.find_all_by_clerkship_id([@clerkship.id, -1]) 
    
    @dxbycats = Diagnosis.dx_by_categories(@clerkship.id)
    @dx_names = @dxbycats.map { |dxc| "'#{dxc.category_name} > #{dxc.name}'"}.join(",")
    @dx_hash = @dxbycats.map { |dxc| "'#{dxc.category_name} > #{dxc.name}' : #{dxc.id}"}.join(",")
    @proc_names = @procedures.collect { |proc| "'#{proc.name}'" }.join(",")
    @proc_hash = @procedures.collect { |proc| "'#{proc.name}' : #{proc.id}" }.join(",")
    
  	respond_to do |format|
      	format.html # edit.html.erb
      	format.xml  { render :xml => @encounter }
    end    
  end

  # POST /encounters
  # POST /encounters.xml
  def create
    if @user.primary_role != "Student"
      render :file => "public/401.html", :status => :unauthorized 
      return
    end
    
    hx = hnp_flag(params[:hx])
    px = hnp_flag(params[:px])
    
    @encounter = Encounter.new(params[:encounter])
    @encounter.hx = hx
    @encounter.px = px
    @encounter.creator = @user
    @encounter.updater = @user
    
    primary_problem = params[:primary_problem]
    secondary_problems = params[:secondary_problems]
    procedures_observed = params[:procedures_observed]
    
    respond_to do |format|
      if @encounter.save
        #save single primary problem
        if primary_problem.include? ' > ' then 
        	dx_xref = Diagnosis.find_by_name primary_problem.split(' > ').last
        	dx_other = ''
        else
        	dx_xref = Diagnosis.find_by_name 'Other'
        	dx_other = primary_problem
        end
        
        @edx = @encounter.diagnoses.new("encounter_id" => @encounter.id, "dx_type" => 'P', "dx_id" => dx_xref.id, "other" => dx_other, "created_by" => @user.id, "updated_by" => @user.id)
        @edx.save
        
        #loop and save secondary problems
        for sdx in secondary_problems.split(', ')
    			if sdx.include? ' > ' then 
    				dx_xref = Diagnosis.find_by_name sdx.split(' > ').last
    				dx_other = ''
    			else
    				dx_xref = Diagnosis.find_by_name 'Other'
    				dx_other = sdx
    			end
    			      
          @edx = @encounter.diagnoses.new("encounter_id" => @encounter.id, "dx_type" => 'S', "dx_id" => dx_xref.id, "other" => dx_other, "created_by" => @user.id, "updated_by" => @user.id)
          @edx.save
        
        end #for dx loop
        
        #loop and save procedures observed
        for po in procedures_observed.split(', ')
          
    			if (proc_xref = Procedure.find_by_name(po)) 
    			then 
    				proc_xref = Procedure.find_by_name(po)
    				proc_other = ''
    			else 
    				proc_xref = Procedure.find_by_name('Other')
    				proc_other = po
    			end
          
          @po_new = @encounter.procedures.new("encounter_id" => @encounter.id, "participation_type" => 'O', "procedure_id" => proc_xref.id, "other" => proc_other, "created_by" => @user.id, "updated_by" => @user.id)
          @po_new.save
        end #for procedures observed loop
        
        flash[:notice] = 'Encounter was successfully created.'
        format.html { redirect_to(@encounter) }
        format.xml  { render :xml => @encounter, :status => :created, :location => @encounter }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @encounter.errors, :status => :unprocessable_entity }
      end
    end
  end
  
  # POST /update
  # POST /update.xml
  def update
    if @user.primary_role != "Student"
      render :file => "public/401.html", :status => :unauthorized 
      return
    end
    
    hx = hnp_flag(params[:hx])
    px = hnp_flag(params[:px])

    @encounter = Encounter.find(params[:encounter]['encounter_id'])
    @encounter.update_attributes :dob => params[:encounter]['dob'], :encounter_date => params[:encounter]['encounter_date'], :patient_id => params[:encounter]['patient_id'], :gender => params[:encounter]['gender'], :notes => params[:encounter]['notes'], :clinic_id => params[:encounter]['clinic_id'], :hx => hx, :px => px, :updated_by =>@user.id 
        
    respond_to do |format|
      if @encounter.save
      	#destroy existing problems
      	@encounter.diagnoses.destroy_all
        #save single primary problem
        if params[:encounter]['primary_problem'].include? ' > ' then 
        	dx_xref = Diagnosis.find_by_name params[:encounter]['primary_problem'].split(' > ').last
        	dx_other = ''
        else
        	dx_xref = Diagnosis.find_by_name 'Other'
        	dx_other = params[:encounter]['primary_problem']
        end
        @edx = @encounter.diagnoses.new("encounter_id" => @encounter.id, "dx_type" => 'P', "dx_id" => dx_xref.id, "other" => dx_other, "created_by" => @user.id, "updated_by" => @user.id)
        @edx.save
        
        #loop and save secondary problems
        for sdx in params[:encounter]['secondary_problems'].split(', ')
			if sdx.include? ' > ' then 
				dx_xref = Diagnosis.find_by_name sdx.split(' > ').last
				dx_other = ''
			else
				dx_xref = Diagnosis.find_by_name 'Other'
				dx_other = sdx
			end        
          	@edx = @encounter.diagnoses.new("encounter_id" => @encounter.id, "dx_type" => 'S', "dx_id" => dx_xref.id, "other" => dx_other, "created_by" => @user.id, "updated_by" => @user.id)
          	@edx.save
        end #for dx loop
        #destroy existing procedures
        @encounter.procedures.destroy_all
        #loop and save procedures observed
        for po in params[:encounter]['procedures_observed'].split(', ')
			if (proc_xref = Procedure.find_by_name(po)) 
			then 
				proc_xref = Procedure.find_by_name(po)
				proc_other = ''
			else 
				proc_xref = Procedure.find_by_name('Other')
				proc_other = po
			end
          @po_new = @encounter.procedures.new("encounter_id" => @encounter.id, "participation_type" => 'O', "procedure_id" => proc_xref.id, "other" => proc_other, "created_by" => @user.id, "updated_by" => @user.id)
          @po_new.save
        end #for procedures observed loop
        
        flash[:notice] = 'Encounter was successfully edited.'
        format.html { redirect_to(@encounter) }
        format.xml  { render :xml => @encounter, :status => :created, :location => @encounter }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @encounter.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /encounters/1
  # PUT /encounters/1.xml
  def inplaceupdate
    @encounter = Encounter.find(params[:id])
    @attributes={params[:field]=>params[:value]}
    field = params[:field]
    $fieldval = params[:value]

    respond_to do |format|
      if @encounter.update_attributes(@attributes)
        flash[:notice] = 'Encounter was successfully updated.'
      	#format.html { redirect_to encounters_path }
      	format.js {render :layout => false}
      else
        flash[:notice] = 'Encounter was NOT successfully updated.'
      	#format.html { redirect_to encounters_path }
      	format.js {render :layout => false}
      end
    end  
  end

  # DELETE /encounters/1
  # DELETE /encounters/1.xml
  def destroy
    @encounter = Encounter.find(params[:id])
    @encounter.destroy

    respond_to do |format|
      format.html { redirect_to(encounters_url) }
      format.xml  { head :ok }
    end
  end
  
private
  def hnp_flag(hx_or_px)
  	case
  		when (hx_or_px['O'] == "1" && hx_or_px['P'] == "1")
  			hpx = 'B'
  		when (hx_or_px['O'] == "1" && hx_or_px['P'] == "0") 
  			hpx = 'O'
  		when (hx_or_px['O'] == "0" && hx_or_px['P'] == "1")
  			hpx = 'P'
  		when (hx_or_px['O'] == "0" && hx_or_px['P'] == "0")
  			hpx = 'N'
  		else
  			hpx = 'N'
  	end
  	hpx
  end
  
end
