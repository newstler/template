module Madmin
  class RagController < Madmin::ApplicationController
    def show
      @setting = Setting.instance
    end

    def update
      @setting = Setting.instance

      if @setting.update(rag_params)
        respond_to do |format|
          format.json { head :ok }
          format.html { redirect_to main_app.madmin_rag_path, notice: t("controllers.madmin.rag.update.notice") }
        end
      else
        respond_to do |format|
          format.json { head :unprocessable_entity }
          format.html { redirect_to main_app.madmin_rag_path, alert: @setting.errors.full_messages.join(", ") }
        end
      end
    end

    def rebuild_fts
      Searchable.registry.each do |klass|
        klass.find_each(&:update_search_index)
      end
      redirect_to main_app.madmin_rag_path, notice: t("controllers.madmin.common.rebuild_fts.notice")
    end

    private

    def rag_params
      params.require(:setting).permit(
        :search_tokenizer,
        :rrf_k,
        :max_similarity_distance,
        :chunk_size,
        :chunk_overlap,
        :hybrid_pool_multiplier
      )
    end
  end
end
