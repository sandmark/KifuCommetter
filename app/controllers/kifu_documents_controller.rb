# -*- coding: utf-8 -*-
class KifuDocumentsController < ApplicationController
  respond_to :html, :xml, :js
  before_filter :check_user, :only => [:update, :edit, :destroy]

  RevisionPattern = /Rev\.(\d+)/
  
  def search
    if params[:page].to_i.zero?
      @page = 1
    else
      @page = params[:page].to_i
    end

    @kifu_documents = KifuDocument.search(params[:query]).order(:updated_at.desc).paginate(@page,nil)
    flash.now[:notice] = "#{@kifu_documents.length}件ヒットしました！"
    if not @page.zero?
      @morepage = @page + 1
    else
      @morepage = 2
    end
    @morepage = nil if KifuDocument.search(params[:query]).order(:updated_at.desc).paginate(@page+1, nil).length.zero?
    render :action => :index
  end

  # GET /kifu_documents/1/blogcode
  def blogcode
    @kifu_document = KifuDocument.find params[:id]
    respond_to do |format|
      format.js
    end
  end

  # GET /kifu_documents/toggle_form_visible
  def toggle_form_visible
    respond_to do |format|
      format.js
    end
  end

  # GET  /kifu_documents/1/merge
  # POST /kifu_documents/1/merge
  def merge
    @parent = KifuDocument.find params[:id]

    if request.post? # 新規作成
      @kifu_document = KifuDocument.new params[:kifu_document]
      @kifu_document.parent = @parent

      # Revision関連
      if @parent.title.match RevisionPattern # Rev.? にマッチした場合
        # 数値アップデート
        @rev = @parent.title.scan(RevisionPattern).first.first.to_i
        @parent.title = @parent.title.gsub(RevisionPattern, "Rev.#{@rev+1}")
      else # 新規マージの場合、子の数を数えて Rev.? を付加する
        @size = @parent.all_children.size
        @parent.title = "#{@parent.title} Rev.#{@size+1}"
      end # Rev 操作終わり
      
      # 戦型継承
      @parent.forms.each do |form|
        @kifu_document.forms.push form
      end

      if @kifu_document.save
        find_user
        session[:user].kifu_document_ids[@kifu_document.id] = true
        @parent.children << @kifu_document
        @parent.save!
        respond_with @kifu_document do |format|
          format.html { redirect_to kifu_document_url(@parent),
            :notice => "棋譜【#{@kifu_document.title}】をマージしました！" }
        end
      else # 保存に失敗した
        respond_with @kifu_document
      end
    else                                # GET (フォーム描画)
      @merge         = true             # フォームアクションのため
      @kifu_document = KifuDocument.new # フォーム描画のため
      respond_with @parent
    end
  end

  # GET /kifu_documents/download/1.orig.kif
  def send_original_kifu
    send_data NKF.nkf("-s", KifuDocument.find(params[:id]).kifu)
  end

  # GET /kifu_documents/download/1.kif
  def send_kifu
    send_data NKF.nkf("-s", KifuDocument.find(params[:id]).to_kifu_all.to_s_with_names)
  end

  # GET|POST /kifu_document/newp
  def new_with_plain_kifu
    @page_title = "新規投稿"
    @action = newp_kifu_document_url
    if request.get?
      @kifu_document = KifuDocument.new
      respond_with @kifu_document
    else
      @kifu_document = KifuDocument.new params[:kifu_document]
      @kifu_document.upload = false
      if @kifu_document.save
        respond_with @kifu_document do |format|
          session[:user].kifu_document_ids[@kifu_document.id] = true
          format.html { redirect_to @kifu_document, :notice => "棋譜【#{@kifu_document.title}】を投稿しました！" }
        end
      else
        render :new_with_plain_kifu
      end
    end
  end

  # GET|PUT /kifudocuments/1/editu
  def edit_with_upload
    @page_title = "棋譜情報の編集"
    if request.get?
      @kifu_document = KifuDocument.find params[:id]
      respond_with @kifu_document
    else
      @kifu_document = KifuDocument.find params[:id]
      if @kifu_document.update_attributes params[:kifu_document]
        respond_with @kifu_document do |format|
          format.html { redirect_to @kifu_document, :notice => "棋譜【#{@kifu_document.title}】を更新しました！" }
        end
      else
        render :edit_with_upload
      end
    end
  end

  # GET /kifu_documents/1.kifu
  def kifu
    @kifu_document = KifuDocument.find params[:id]
    @kifu = @kifu_document.to_kifu_all.to_s_with_names
    render :layout => false
  end

  # GET /kifu_documents/1.kif
  # (Shift_JIS)
  def kif
    @kifu_document = KifuDocument.find params[:id]
    @kif = NKF.nkf("-s", @kifu_document.to_kifu_all.to_s_with_names)
    
    render :layout => false
  end

  # GET /kifu_documents
  # GET /kifu_documents.xml
  def index
    if params[:page].to_i.zero?
      @page = 1
    else
      @page = params[:page].to_i
    end

    @kifu_documents = KifuDocument.order(:updated_at.desc).paginate(@page, nil)
    if not @page.zero?
      @morepage = @page + 1 
    else
      @morepage = 2
    end
    @morepage = nil if KifuDocument.paginate(@page+1, nil).length.zero?
    respond_with @kifu_documents
  end

  # GET /kifu_documents/1
  # GET /kifu_documents/1.xml
  def show
    @kifu_document = KifuDocument.find(params[:id])
    @kifu = Kifu::Kifu.new @kifu_document.kifu
    @form = Form.new
    @comment = Comment.new

    @page = params[:page].to_i or 1
    @comments = Comment.of_kifu_document(@kifu_document.id).paginate(@page, nil)
    if not @page.zero?
      @morepage = @page + 1 
    else
      @morepage = 2
    end
    @morepage = nil if Comment.of_kifu_document(@kifu_document.id).paginate(@page+1, nil).length.zero?

    respond_with @kifu_documents
  end

  # GET /kifu_documents/new
  # GET /kifu_documents/new.xml
  def new
    @kifu_document = KifuDocument.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @kifu_document }
    end
  end

  # GET /kifu_documents/1/edit
  def edit
    @kifu_document = KifuDocument.find(params[:id])
    respond_with @kifu_document
  end

  # POST /kifu_documents
  # POST /kifu_documents.xml
  def create
    @kifu_document = KifuDocument.new(params[:kifu_document])

    respond_to do |format|
      if @kifu_document.save
        session[:user].kifu_document_ids[@kifu_document.id] = true
        format.html { redirect_to(@kifu_document, :notice => "棋譜【#{@kifu_document.title}】を投稿しました！") }
        format.xml  { render :xml => @kifu_document, :status => :created, :location => @kifu_document }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @kifu_document.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /kifu_documents/1
  # PUT /kifu_documents/1.xml
  def update
    @kifu_document = KifuDocument.find(params[:id])

    respond_with @kifu_document do |format|
      if @kifu_document.update_attributes(params[:kifu_document])
        format.html { redirect_to(@kifu_document, :notice => "【#{@kifu_document.title}】を更新しました！") }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @kifu_document.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /kifu_documents/1
  # DELETE /kifu_documents/1.xml
  def destroy
    @kifu_document = KifuDocument.find(params[:id])
    @kifu_document.destroy

    respond_to do |format|
      format.html { redirect_to(kifu_documents_url) }
      format.xml  { head :ok }
    end
  end

  protected
  def check_user
    if not session[:user].kifu_document_ids.has_key? params[:id].to_i
      redirect_to kifu_documents_url, :notice => "許可されていない操作です。"
    end
  end

  private
#  def merged_kifu kifu_document
#    if kifu_document.all_children.blank?
#      if kifu_document.comments.blank?
#        kifu_document.kifu
#      else
#        merge_comments(kifu_document).to_s_with_names
#      end
#    else
#      k1 = Kifu::Kifu.new kifu_document.kifu, kifu_document.uploaded_by
#      logger.debug kifu_document.all_children.inspect
#      kifu_document.all_children.each do |child|
#        k2 = Kifu::Kifu.new child.kifu, child.uploaded_by
#        k1 = k1 & k2
#      end
#      return merge_comments(k1, .to_s_with_names
#    end
#  end
end
