
#
# CBRAIN Project
#
# CbrainTask subclass
#
# Original author: Mathieu Desrosiers
#
# $Id$
#

#A subclass of CbrainTask::ClusterTask to run mnc2nii.
class CbrainTask::Mnc2nii < CbrainTask::ClusterTask

  Revision_info="$Id$"

  include RestartableTask # This task is naturally restartable
  include RecoverableTask # This task is naturally recoverable

  def setup #:nodoc:
    params      = self.params
    minc_colid = params[:mincfile_id]  # the ID of a FileCollection
    minc_col   = Userfile.find(minc_colid)

    unless minc_col
      self.addlog("Could not find active record entry for file #{minc_colid}")
      return false
    end

    minc_col.sync_to_cache
    cachename = minc_col.cache_full_path
    safe_symlink(cachename,"minc_col.mnc")

    params[:data_provider_id] = mincfile.data_provider_id if params[:data_provider_id].blank?

    true
  end

  def cluster_commands #:nodoc:
    params       = self.params
    data_type = params[:data_type]

    if data_type == "default"
      data_type = ""
    else
      data_type = "-#{data_type}"
    end

    file_format = params[:file_format]
    file_format = "-#{file_format}"

    [
      "source #{CBRAIN::Quarantine_dir}/init.sh",
      "mnc2nii #{data_type} #{file_format} minc_col.mnc"
    ]
  end

  def save_results #:nodoc:
    params      = self.params
    minc_colid = params[:mincfile_id]
    minc_col   = Userfile.find(minc_colid)
    group_id   = minc_col.group_id

    user_id          = self.user_id
    data_provider.id = params[:data_provider_id]

    out_files = Dir.glob("*.{img,hdr,nii,nia}")
    niifiles = []
    out_files.each do |file|
      self.addlog(file)
      niifile = safe_userfile_find_or_new(SingleFile,
        :name             => File.basename(minc_col.cache_full_path,".mnc")+File.extname(file),
        :user_id          => user_id,
        :group_id         => group_id,
        :data_provider_id => data_provider_id,
        :task             => "Mnc2nii"
      )
      niifile.cache_copy_from_local_file(file)
      if niifile.save
        niifile.move_to_child_of(minc_col)
        self.addlog("Saved new Nifti file ")
        niifiles << niifile
      else
        self.addlog("Could not save back result file #{niifile.name}")
      end
    end

    params[:niifile_ids] = niifiles.map &:id
    self.addlog_to_userfiles_these_created_these( [ minc_col ], niifiles )

    true
  end

end