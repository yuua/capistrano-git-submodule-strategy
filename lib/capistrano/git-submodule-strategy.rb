require 'capistrano/git'

class Capistrano::Git
  module SubmoduleStrategy
    # do all the things a normal capistrano git session would do
    include Capistrano::Git::DefaultStrategy

    def test
      test! " [ -f #{repo_path}/HEAD ] "
    end

    def check
      unless test!(:git, :'ls-remote', repo_url)
        context.error "Repo `#{repo_url}` does not exists"
        return false
      end

      if context.capture(:git, :'ls-remote', repo_url, fetch(:branch)).empty?
        context.error "Branch `#{fetch(:branch)}` not found in repo `#{repo_url}`"
        return false
      end

      true
    end

    def clone
      git :clone, '--mirror', repo_url, repo_path
    end

    def update
      git :remote, :update
    end

    # put the working tree in a release-branch,
    # make sure the submodules are up-to-date
    # and copy everything to the release path
    def release
      unless context.test(:test, '-e', release_path) && context.test("ls -A #{release_path} | read linevar")
        git :clone, "--reference #{repo_path}", (fetch(:git_keep_meta, false) ? '' : '--depth=1'), '-b', fetch(:branch), repo_url, release_path
        context.within_only release_path do
          git :submodule, 'update', '--init', '--recursive', fetch(:git_submodule_keep_meta,false) ? '' : '--depth=1'
        end
        unless fetch(:git_keep_meta, false)
          verbose = Rake.application.options.trace ? 'v' : ''
          context.execute("find #{release_path} -name '.git*' | xargs -I {} rm -rf#{verbose} '{}'")
        end
      end
    end
  end
end

# shit hack to execute command only in specified directory
module SSHKit
  module Backend
    class Abstract
      def within_only(directory, &block)
        pwd = @pwd
        @pwd = []
        within directory, &block
      ensure
        @pwd = pwd
      end
    end
  end
end
