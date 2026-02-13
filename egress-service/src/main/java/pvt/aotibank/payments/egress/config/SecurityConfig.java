package pvt.aotibank.egress.config;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.core.authority.AuthorityUtils;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
public class SecurityConfig {
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http.csrf(AbstractHttpConfigurer::disable)
            .authorizeHttpRequests(auth -> auth.anyRequest().authenticated())
            .x509(x509 -> x509.subjectPrincipalRegex("CN=(.*?)(?:,|$)"));
        return http.build();
    }

    @Bean
    public UserDetailsService userDetailsService() {
        return username -> {
            // FIX: Allow 'dispense' (Get Client) AND 'client' (fallback)
            if (username.contains("dispense") || username.equals("client")) {
                return new User(username, "", AuthorityUtils.commaSeparatedStringToAuthorityList("ROLE_USER"));
            }
            throw new UsernameNotFoundException("User not found: " + username);
        };
    }
}
